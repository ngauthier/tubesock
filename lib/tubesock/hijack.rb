require 'active_support/concern'
# Interact with WebSocket connections in rails.
# Example:
#   # The widget controller's `show` lets you edit a widget in
#   # real time. The websocket frames from the client should be in JSON, for
#   # example:
#   #    socket.send(JSON.stringify({name: "foo"}));
#   class WidgetController < ApplicationController
#     include Tubesock::Hijack
#     def show
#       widget = Widget.find params[:id]
#       hijack do |tubesock|
#         tubesock.onopen do
#           widget.update_attribute :editing, true
#         end
#         tubesock.onmessage do |message|
#           widget.update_attribute :name, message["name"]
#         end
#         tubesock.onclose do
#           widget.update_attribute :editing, true
#         end
#       end
#     end
#   end
module Tubesock::Hijack
  extend ActiveSupport::Concern

  included do
    def hijack
      sock = Tubesock.hijack(request.env)
      yield sock
      sock.onclose do
        ActiveRecord::Base.clear_active_connections! if defined? ActiveRecord
      end
      sock.listen
      render text: nil, status: -1
    end
  end
end
