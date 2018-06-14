module Kemal
  # Handles all the exceptions, including 404, custom errors and 500.
  class ExceptionHandler
    include HTTP::Handler
    INSTANCE = new

    def call(context : HTTP::Server::Context)
      call_next(context)
    rescue ex : Exception
      if Kemal.config.exception_mapped_handlers.has_key?(ex.class)
        Kemal.config.exception_mapped_handlers[ex.class].call(context, ex)
      elsif ex.is_a? Kemal::Exceptions::RouteNotFound
        return call_exception_with_status_code(context, ex, 404)
      elsif ex.is_a? Kemal::Exceptions::CustomException
        return call_exception_with_status_code(context, ex, context.response.status_code)
      end

      log("Exception: #{ex.inspect_with_backtrace}")
      return call_exception_with_status_code(context, ex, 500) if Kemal.config.error_handlers.has_key?(500)
      verbosity = Kemal.config.env == "production" ? false : true
      return render_500(context, ex.inspect_with_backtrace, verbosity)
    end

    private def call_exception_with_status_code(context : HTTP::Server::Context, exception : Exception, status_code : Int32)
      if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(status_code)
        context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
        context.response.print Kemal.config.error_handlers[status_code].call(context, exception)
        context.response.status_code = status_code
        context
      end
    end
  end
end
