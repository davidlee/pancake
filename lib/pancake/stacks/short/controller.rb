module Pancake
  module Stacks
    class Short
      inheritable_inner_classes :Controller

      class Controller
        extend  Mixins::Publish
        include Mixins::Render
        include Mixins::RequestHelper

        class_inheritable_accessor :_handle_exception
        
        DEFAULT_EXCEPTION_HANDLER = lambda do |error|
          klass = case error
                  when Class
                    error
                  else
                    error.class
                  end
          "#{klass.name}: #{klass.description}"
        end unless defined?(DEFAULT_EXCEPTION_HANDLER)
        
        # @api private
        def self.call(env)
          app = new(env)
          app.dispatch!
        end

        # @api public
        attr_accessor :status

        def initialize(env)
          @env, @request = env, Rack::Request.new(env)
          @status = 200
        end

        # Provides access to the request params
        # @api public
        def params
          request.params
        end

        # Dispatches to an action based on the params["action"] parameter
        def dispatch!
          params["action"] ||= params[:action]
          params["action"] ||= "index"
          params[:format]  ||= params["format"]
 
          # Check that the action is available
          raise Errors::NotFound, "No Action Found" unless allowed_action?(params["action"])
          
          @action_opts  = actions[params["action"]]
          if params[:format]
            @content_type, ct, @mime_type = Pancake::MimeTypes.negotiate_by_extension(params[:format].to_s, @action_opts.formats)
          else
            @content_type, ct, @mime_type = Pancake::MimeTypes.negotiate_accept_type(env["HTTP_ACCEPT"], @action_opts.formats)
          end
          
          raise Errors::NotAcceptable unless @content_type
 
          # set the response header
          headers["Content-Type"] = ct
          
          Rack::Response.new(self.send(params["action"]), status, headers).finish
        rescue Errors::HttpError => e
          handle_request_exception(e)
        rescue Exception => e
          server_error = Errors::Server.new
          server_error.exceptions << e
          handle_request_exception(server_error)
        end

        def content_type
          @content_type
        end

        def self.handle_exception(&block)
          if block_given?
            self._handle_exception = block
          else
            self._handle_exception || DEFAULT_EXCEPTION_HANDLER
          end
        end
          
        def handle_request_exception(error)
          self.status = error.code
          result = instance_exec error, &self.class.handle_exception
          Rack::Response.new(result, status, headers).finish
        end
        
        private
        def allowed_action?(action)
          self.class.actions.include?(action.to_s)
        end

      end # Controller

    end # Short
  end # Stacks
end # Pancake
