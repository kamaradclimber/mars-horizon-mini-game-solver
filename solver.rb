#!/usr/bin/env ruby
#

# rubocop:disable Lint/MissingCopEnableDirective
# rubocop:disable Lint/UnneededCopDisableDirective
# rubocop:disable Metrics/LineLength
# rubocop:disable Style/Documentation
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/AbcSize
# rubocop:disable Style/TrailingCommaInArrayLiteral

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
  def initialize(resources)
    @resources = resources.dup
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
  def initialize(transformations, objective, max_round, init_state)
    @transformations = transformations
    @objective = objective
    @max_round = max_round
    @current_state = init_state
  end

  # return nil if nothing is possible
  # return [] if we already are at the solution
  # return [<Transformation>] if it leads to the solution
  def solve
    return [] if @current_state.achieved?(@objective)
    return nil if @max_round <= 0

    possible_transformations = @transformations.select { |transformation| @current_state.can_apply?(transformation) }

    sorted_transformations = possible_transformations.sort_by do |transformation|
      future_state = @current_state.dup.apply(transformation)
      future_state.distance_of(@objective)
    end
    return nil if sorted_transformations.empty?

    sorted_transformations.lazy.map do |transformation|
      future_state = @current_state.dup.apply(transformation)
      world = World.new(@transformations, @objective, @max_round - 1, future_state)
      res = world.solve
      [transformation] + res if res
    end.select(&:itself).first
  end
end

class OptimalSolver
  def initialize(transformations, objective, max_rounds, init_state)
    @transformations = transformations
    @objective = objective
    @max_rounds = max_rounds
    @init_state = init_state
  end

  def run
    best_sol = nil
    new_best_sol = Object.new
    rounds = @max_rounds
    until rounds.zero? || new_best_sol.nil?
      print "Trying to solve in #{rounds} rounds..."
      best_sol = new_best_sol
      w = World.new(@transformations, @objective, rounds, @init_state)
      new_best_sol = w.solve
      rounds -= 1
      puts (new_best_sol ? 'OK' : 'NOK')
    end
    best_sol
  end
end

# Dummy test1
state = State.new(coms: 0, electricity: 2)
transformations = [
  Transformation.new(inputs: {}, outputs: { electricity: 1 }),
  Transformation.new(inputs: { electricity: 1 }, outputs: { data: 1 }),
  Transformation.new(inputs: { electricity: 1 }, outputs: { coms: 1 }),
]
objective = { data: 2, coms: 1 }

w = World.new(transformations, objective, 4, state)
solution = w.solve
raise 'Could not find any solution' unless solution

solution.each do |t|
  puts t
end

# Mars flyby - part 2
puts '-----'
state = State.new(electricity: 5)
transformations = [
  Transformation.new(inputs: {}, outputs: { electricity: 1 }),

  Transformation.new(inputs: { electricity: 2 }, outputs: { coms: 2 }),
  Transformation.new(inputs: { data: 1 }, outputs: { coms: 2, nav: 1 }),
  Transformation.new(inputs: { nav: 1 }, outputs: { coms: 2, data: 1 }),

  Transformation.new(inputs: { electricity: 1 }, outputs: { data: 2 }),
  Transformation.new(inputs: { electricity: 1, coms: 2 }, outputs: { data: 3 }),
  Transformation.new(inputs: { nav: 2 }, outputs: { data: 3 }),

  Transformation.new(inputs: { electricity: 1 }, outputs: { nav: 2 }),
  Transformation.new(inputs: { data: 1 }, outputs: { coms: 1, nav: 2 }),
  Transformation.new(inputs: { coms: 1, electricity: 1 }, outputs: { nav: 4 }),
]
objective = { coms: 5, data: 8, nav: 3 }

max_rounds = 12
solver = OptimalSolver.new(transformations, objective, max_rounds, state)
solution = solver.run
raise 'Could not find any solution' unless solution

solution.each_with_index do |t, i|
  puts "#{i + 1}: #{t}"
end
puts "Using #{solution.size} rounds out of #{max_rounds}"