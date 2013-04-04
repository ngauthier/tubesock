# Tubesock

Tubesock lets you use websockets from rack and rails 4+ by using Rack's new hijack interface to access the underlying socket connection.

In contrast to other websocket libraries, Tubesock does not use a reactor (read: no eventmachine). Instead, it leverages Rails 4's new full-stack concurrency support. Note that this means you must use a concurrent server. We recommend Puma.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tubesock'
# currently, the ability to setup a websocket from rack is only
# available on my fork. If/when the PR is merged this will become a gem dependency
gem 'websocket', github: "ngauthier/websocket-ruby"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tubesock

## Usage

### Rack

To use Tubesock with rack, you need to hijack the rack environment and then return an asynchronous response. For example:

```ruby
def self.call(env)
  if websocket?(env)
    tubesock = hijack(env)
    tubesock.listen
    tubesock.onmessage do |message|
      puts "Got #{message}"
    end
    [ -1, {}, [] ]
  else
    [404, {'Content-Type' => 'text/plain'}, ['Not Found']]
  end
end
```

NOTE: I have not gotten the above to work just yet with just puma or thin. For now, check out the rails example.

### Rails 4+

On Rails 4 there is a module you can use called `Tubesock::Hijack`. In a controller:

```ruby
class ChatController < ApplicationController
  include Tubesock::Hijack

  def chat
    hijack do |tubesock|
      tubesock.onopen do
        tubesock.send_data message: "Hello, friend"
      end

      tubesock.onmessage do |data|
        tubesock.send_data message: "You said: #{data[:message]}"
      end
    end
  end
end
```

For a full example, check out [Tubesock Example](http://github.com/ngauthier/tubesock-example).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
