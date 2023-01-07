# frozen_string_literal: true

class GraphqlChannel < ApplicationCable::Channel
  def subscribed
    @subscription_ids = []
  end

  # rubocop:disable Metrics/MethodLength
  def execute(data)
    query = data['query']
    variables = ensure_hash(data['variables'])
    operation_name = data['operationName']
    context = {
      # Re-implement whatever context methods you need
      # in this channel or ApplicationCable::Channel
      # current_user: current_user,
      # Make sure the channel is in the context
      channel: self
    }

    result = TentaclesSchema.execute(
      query:,
      context:,
      variables:,
      operation_name:
    )

    payload = {
      result: result.to_h,
      more: result.subscription?
    }

    # Track the subscription here so we can remove it
    # on unsubscribe.
    @subscription_ids << result.context[:subscription_id] if result.context[:subscription_id]

    transmit(payload)
  end
  # rubocop:enable Metrics/MethodLength

  def unsubscribed
    @subscription_ids.each do |sid|
      TentaclesSchema.subscriptions.delete_subscription(sid)
    end
  end

  private

  # rubocop:disable Metrics/MethodLength
  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      if ambiguous_param.present?
        ensure_hash(JSON.parse(ambiguous_param))
      else
        {}
      end
    when Hash, ActionController::Parameters
      ambiguous_param
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param}"
    end
  end
  # rubocop:enable Metrics/MethodLength
end
