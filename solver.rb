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
    return [] if @current_state.distance_of(@objective).zero?
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

state = State.new(coms: 0, electricity: 2)
transformations = [
  Transformation.new(inputs: {}, outputs: { electricity: 1 }),
  Transformation.new(inputs: { electricity: 1 }, outputs: { data: 1 }),
  Transformation.new(inputs: { electricity: 1 }, outputs: { coms: 1 }),
]
objective = { data: 2, coms: 1}

w = World.new(transformations, objective, 4, state)
solution = w.solve
raise 'Could not find any solution' unless solution

solution.each do |t|
  puts t
end
