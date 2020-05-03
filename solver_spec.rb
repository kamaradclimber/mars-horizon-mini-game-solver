require_relative 'solver'
require 'rspec'

describe World do
  context 'when loose_1thrust_every_3rounds is true' do
    subject do
      World.new(transformations, objective, remaining_rounds, init_state, loose_1thrust_every_3rounds: true).solve
    end

    let(:transformations) do
      [
        Transformation.new(inputs: {}, outputs: { electricity: 1 }),
        Transformation.new(inputs: { electricity: 2 }, outputs: { thrust: 2 }),
      ]
    end

    let(:objective) do
      { thrust: 3 }
    end

    let(:remaining_rounds) { 12 }
    let(:init_state) do
      State.new(apple: 3)
    end

    # this solves and return resulting state
    let(:result_state) do
      plan = subject
      plan.inject(init_state) do |state, transformation|
        state.apply(transformation)
      end
    end

    it 'finds a solution' do
      expect(subject).not_to be_nil
    end

    it 'is a valid solution' do
      result_state.achieved?(objective)
    end

    it 'accounts for thrust loss' do
      thrust_transformation = transformations.find { |t| t.outputs.key?(:thrust) }
      plan = subject
      expect(plan.count { |t| t == thrust_transformation }).to be > 2
    end
  end
end
