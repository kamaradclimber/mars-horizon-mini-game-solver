require 'timeout'

module Emojifier
  def convert(type)
    case type
    when :electricity
      '⚡'
    when :coms
      '📻'
    when :data
      '💾'
    when :heat
      '🔥'
    when :thrust
      '🚀'
    when :nav
      '🧭'
    else
      " #{type}"
    end
  end
end

class Transformation
  include Emojifier

  def initialize(inputs:, outputs:)
    @inputs = inputs
    @outputs = outputs
  end
  attr_reader :inputs, :outputs

  def to_s
    ins = inputs.map { |r, q| "#{q}#{convert(r)}" }.join(', ')
    ous = outputs.map { |r, q| "#{q}#{convert(r)}" }.join(', ')
    "#{ins} => #{ous}"
  end

  def inspect
    to_s
  end
end

class State
  include Emojifier

  attr_reader :resources
  def initialize(resources)
    @resources = resources.dup
  end

  def to_s
    resources.map { |r, q| "#{q}#{convert(r)}" }.join(', ')
  end

  def inspect
    to_s
  end

  def can_apply?(transformation)
    transformation.inputs.all? do |resource, quantity|
      case resource
      when :angle # special case for negative resource, we can always afford them
        true
      else
        @resources[resource] && @resources[resource] >= quantity
      end
    end
  end

  def dup
    State.new(@resources)
  end

  def apply(transformation)
    transformation.inputs.each do |resource, quantity|
      @resources[resource] ||= 0
      @resources[resource] -= quantity
    end
    transformation.outputs.each do |resource, quantity|
      @resources[resource] ||= 0
      @resources[resource] += quantity
    end
    self
  end

  def distance_of(objective)
    objective.map do |resource, quantity|
      available = @resources[resource] || 0
      case quantity
      when Integer
        (quantity - [available, quantity].min)**2
      when Range
        if quantity.cover?((@resources[resource] || 0))
          0
        else
          target = (quantity.max - quantity.min) / 2
          (available - target)**2
        end
      else
        raise NotImplementedError, "#{quantity.class} is not handled"
      end
    end.sum
  end

  def achieved?(objective)
    objective.all? do |resource, quantity|
      case quantity
      when Integer
        (@resources[resource] || 0) >= quantity
      when Range
        quantity.cover?((@resources[resource] || 0))
      else
        raise NotImplementedError, "#{quantity.class} is not handled"
      end
    end
  end
end

class Solution
  include Enumerable
  def initialize(init_state, steps, total_rounds, objective, opts)
    @init_state = init_state
    @steps = steps
    @total_rounds = total_rounds
    @objective = objective
    @opts = opts.merge(max_rounds: total_rounds)
  end

  def size
    count
  end

  def inspect
    output = ''
    last = nil
    each_with_index do |t, i|
      output += "\nState at stage #{i}: #{t[:state]},  recommended action: #{t[:next]}"
      last = t[:state]
    end
    output += "\n\nObjective #{last.achieved?(@objective) ? '👍' : '❌'}: #{@objective.inspect}"
    output += "\nUsing #{size} rounds out of #{@total_rounds}"
    output
  end

  def each
    current_state = @init_state
    remaining_rounds = @total_rounds
    elapsed_rounds = 0
    @steps.map do |transformation|
      yield({ state: current_state, next: transformation })
      w = World.new([], @objective, remaining_rounds, current_state, @opts)
      elapsed_rounds += 1
      remaining_rounds -= 1
      current_state = w.apply(transformation, elapsed_rounds)
    end
    yield({ state: current_state, next: nil })
  end
end

class World
  def initialize(transformations, objective, remaining_rounds, init_state, opts = {})
    @transformations = transformations
    @objective = objective
    @remaining_rounds = remaining_rounds
    @current_state = init_state
    @opts = opts
    @loose_1thrust_every_3rounds = opts[:loose_1thrust_every_3rounds] || false
    @max_heat = opts[:max_heat]
    @with_crew = opts[:with_crew] || false
    @heat_incr = opts[:heat_incr] || 2
    @rounds_per_turn = opts[:rounds_per_turn] || 3
  end

  # @returns nil in case of mission failure (overheat for instance)
  def apply(transformation, elapsed_rounds)
    future_state = @current_state.dup.apply(transformation)
    if elapsed_rounds > 0 && (elapsed_rounds % @rounds_per_turn).zero?
      if @loose_1thrust_every_3rounds
        r = future_state.resources
        r[:thrust] -= 1 if r[:thrust] && r[:thrust] > 0
      end
      if @max_heat
        r = future_state.resources
        r[:heat] ||= 0
        return nil if r[:heat] >= @max_heat # heat failure

        r[:heat] += @heat_incr
      end
      if @with_crew
        r = future_state.resources
        r[:crew] = @with_crew # reset crew
      end
    end
    future_state
  end

  # return nil if nothing is possible
  # return [] if we already are at the solution
  # return [<Transformation>] if it leads to the solution
  def solve
    return [] if @current_state.achieved?(@objective)
    return nil if @remaining_rounds <= 0

    possible_transformations = @transformations.select { |transformation| @current_state.can_apply?(transformation) }

    sorted_transformations = possible_transformations.sort_by do |transformation|
      future_state = @current_state.dup.apply(transformation)
      future_state.distance_of(@objective)
    end
    return nil if sorted_transformations.empty?

    sorted_transformations.lazy.map do |transformation|
      elapsed_rounds = @opts[:max_rounds] - @remaining_rounds - 1
      future_state = apply(transformation, elapsed_rounds)
      return nil unless future_state # apply can returns nil in case of error

      world = World.new(@transformations, @objective, @remaining_rounds - 1, future_state, @opts)
      res = world.solve
      [transformation] + res if res
    end.select(&:itself).first
  end
end

class OptimalSolver
  def initialize(transformations, objective, max_rounds, init_state, opts = {})
    @transformations = transformations
    @objective = objective
    @max_rounds = max_rounds
    @init_state = init_state
    @opts = opts
    @opts.merge!(max_rounds: @max_rounds)
  end

  def run
    best_sol = nil
    new_best_sol = Object.new
    rounds = @max_rounds
    until rounds.zero? || new_best_sol.nil?
      print "Trying to solve in #{rounds} rounds..."
      best_sol = new_best_sol
      w = World.new(@transformations, @objective, rounds, @init_state, @opts)
      new_best_sol = begin
                       Timeout.timeout(15) { w.solve }
                     rescue Timeout::Error
                       print 'timeout...'
                       nil
                     end
      puts(new_best_sol ? 'OK' : 'NOK')
      rounds -= 1
    end
    Solution.new(@init_state, best_sol, @max_rounds, @objective, @opts)
  end
end
