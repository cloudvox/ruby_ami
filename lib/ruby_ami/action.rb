module RubyAMI
  ##
  # Each time AMI#send_action is invoked, a new Action is instantiated.
  #
  class Action
    attr_reader :name, :headers, :action_id, :response_resource

    CAUSAL_EVENT_NAMES = %w[queuestatus sippeers iaxpeers parkedcalls dahdishowchannels coreshowchannels
                            dbget status agents konferencelist] unless defined? CAUSAL_EVENT_NAMES

    def initialize(name, response_resource, headers = {})
      @name       = name.to_s.downcase.freeze
      @headers    = headers.stringify_keys.freeze
      @action_id  = UUIDTools::UUID.random_create
      @response_resource = response_resource
    end

    def replies_with_action_id?
      !UnsupportedActionName::UNSUPPORTED_ACTION_NAMES.include? name
    end

    ##
    # When sending an action with "causal events" (i.e. events which must be collected to form a proper
    # response), AMI should send a particular event which instructs us that no more events will be sent.
    # This event is called the "causal event terminator".
    #
    # Note: you must supply both the name of the event and any headers because it's possible that some uses of an
    # action (i.e. same name, different headers) have causal events while other uses don't.
    #
    # @param [String] name the name of the event
    # @param [Hash] the headers associated with this event
    # @return [String] the downcase()'d name of the event name for which to wait
    #
    def has_causal_events?
      CAUSAL_EVENT_NAMES.include? name
    end

    ##
    # Used to determine the event name for an action which has causal events.
    #
    # @param [String] action_name
    # @return [String] The corresponding event name which signals the completion of the causal event sequence.
    #
    def causal_event_terminator_name
      return unless has_causal_events?
      case name
      when "sippeers", "iaxpeers"
        "peerlistcomplete"
      when "dbget"
        "dbgetresponse"
      when "konferencelist"
        "conferencelistcomplete"
      else
        name + "complete"
      end
    end

    ##
    # Converts this action into a protocol-valid String, ready to be sent over a socket.
    #
    def to_s
      @textual_representation ||= (
          "Action: #{@name}\r\nActionID: #{@action_id}\r\n" +
          @headers.map { |(key,value)| "#{key}: #{value}" }.join("\r\n") +
          (@headers.any? ? "\r\n\r\n" : "\r\n")
      )
    end

    ##
    # This class will be removed once this AMI library fully supports all known protocol anomalies.
    #
    class UnsupportedActionName < ArgumentError
      UNSUPPORTED_ACTION_NAMES = %w[queues] unless defined? UNSUPPORTED_ACTION_NAMES

      # Blacklist some actions depends on the Asterisk version
      def self.preinitialize(version)
        if version < 1.8
          %w[iaxpeers muteaudio mixmonitormute aocmessage].each do |action|
            UNSUPPORTED_ACTION_NAMES << action
          end
        end
      end

      def initialize(name)
        super "At the moment this AMI library doesn't support the #{name.inspect} action because it causes a protocol anomaly. Support for it will be coming shortly."
      end
    end
  end
end # RubyAMI
