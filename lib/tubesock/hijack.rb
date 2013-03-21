require 'active_support/concern'
class Tubesock
  module Hijack
    extend ActiveSupport::Concern

    included do
      def hijack
        if Tubesock.websocket?(env)
          sock = Tubesock.hijack(env)
          yield sock
          sock.onclose do
            ActiveRecord::Base.clear_active_connections!
          end
          sock.listen
          render text: nil, status: -1
        else
          render text: "Not found", status: :not_found
        end
      end
    end

    module ClassMethods
    end
  end
end
