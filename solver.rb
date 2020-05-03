require 'timeout'

class Transformation
  def initialize(inputs:, outputs:)
    @inputs = inputs
    @outputs = outputs
  end
  attr_reader :inputs, :outputs

  def to_s
    ins = inputs.map { |r, q| "#{q} #{r}" }.join(', ')
    ous = outputs.map { |r, q| "#{q} #{r}" }.join(', ')
    "#{ins} => #{ous}"
  end
end

class State
  attr_reader :resources
  def initialize(resources)
    @resources = resources.dup
  end

  def to_s
    resources.map { |r, q| "#{q} #{r}" }.join(', ')
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
      future_state = @current_state.dup.apply(transformation)
      # TODO(g.seux): we should compute according to number of elapsed rounds instead
      if @loose_1thrust_every_3rounds && ((@remaining_rounds - 1) % @rounds_per_turn).zero?
        r = future_state.resources
        r[:thrust] -= 1 if r[:thrust] && r[:thrust] > 0
      end
      if @max_heat && ((@remaining_rounds - 1) % @rounds_per_turn).zero?
        r = future_state.resources
        r[:heat] ||= 0
        return nil if r[:heat] >= @max_heat # heat failure

        r[:heat] += @heat_incr
      end
      if @with_crew && ((@remaining_rounds - 1) % @rounds_per_turn).zero?
        r = future_state.resources
        r[:crew] = @with_crew # reset crew
      end
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
    best_sol
  end
end
