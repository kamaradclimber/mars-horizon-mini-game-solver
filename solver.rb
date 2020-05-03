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
      @resources[resource] && @resources[resource] >= quantity
    end
  end

  def dup
    State.new(@resources)
  end

  def apply(transformation)
    transformation.inputs.each do |resource, quantity|
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
      if available >= quantity
        0
      else
        (quantity - available)**2
      end
    end.sum
  end

  def achieved?(objective)
    objective.all? do |resource, quantity|
      (@resources[resource] || 0) >= quantity
    end
  end
end

class World
  def initialize(transformations, objective, remaining_rounds, init_state,
                 loose_1thrust_every_3rounds: false, max_heat: nil, with_crew: false,
                 heat_incr: 2)
    @transformations = transformations
    @objective = objective
    @remaining_rounds = remaining_rounds
    @current_state = init_state
    @loose_1thrust_every_3rounds = loose_1thrust_every_3rounds
    @max_heat = max_heat
    @with_crew = with_crew
    @heat_incr = heat_incr
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
      if @loose_1thrust_every_3rounds && ((@remaining_rounds - 1) % 3).zero?
        r = future_state.resources
        r[:thrust] -= 1 if r[:thrust] && r[:thrust] > 0
      end
      if @max_heat && ((@remaining_rounds - 1) % 3).zero?
        r = future_state.resources
        r[:heat] ||= 0
        r[:heat] += @heat_incr
        return nil if r[:heat] >= 5 # heat failure
      end
      if @with_crew && ((@remaining_rounds - 1) % 4).zero? # FIXME: every 4 round is hard coded
        r = future_state.resources
        r[:crew] = @with_crew # reset crew
      end
      world = World.new(@transformations, @objective, @remaining_rounds - 1, future_state,
                        loose_1thrust_every_3rounds: @loose_1thrust_every_3rounds, max_heat: @max_heat, with_crew: @with_crew,
                        heat_incr: @heat_incr)
      res = world.solve
      [transformation] + res if res
    end.select(&:itself).first
  end
end

class OptimalSolver
  def initialize(transformations, objective, max_rounds, init_state,
                 loose_1thrust_every_3rounds: false, max_heat: nil, with_crew: false,
                 heat_incr: 2)
    @transformations = transformations
    @objective = objective
    @max_rounds = max_rounds
    @init_state = init_state
    @loose_1thrust_every_3rounds = loose_1thrust_every_3rounds
    @max_heat = max_heat
    @with_crew = with_crew
    @heat_incr = heat_incr
  end

  def run
    best_sol = nil
    new_best_sol = Object.new
    rounds = @max_rounds
    until rounds.zero? || new_best_sol.nil?
      print "Trying to solve in #{rounds} rounds..."
      best_sol = new_best_sol
      w = World.new(@transformations, @objective, rounds, @init_state, loose_1thrust_every_3rounds: @loose_1thrust_every_3rounds, max_heat: @max_heat, with_crew: @with_crew, heat_incr: @heat_incr)
      new_best_sol = begin
                       Timeout.timeout(15) { w.solve }
                     rescue Timeout::Error
                       print 'timeout...'
                       nil
                     end
      puts(new_best_sol ? 'OK' : 'NOK')
      # if new_best_sol
      #  puts "  Known solution in #{rounds} rounds"
      #  new_best_sol.each do |transition|
      #    print '  '
      #    puts transition
      #  end
      # end
      rounds -= 1
    end
    best_sol
  end
end
