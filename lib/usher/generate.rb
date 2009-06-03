class Usher
  class Generators
    
    class URL
    
      def initialize(usher)
        @usher = usher
      end
    
      # Generates a completed URL based on a +route+ or set of optional +params+
      #   
      #   set = Usher.new
      #   route = set.add_named_route(:test_route, '/:controller/:action')
      #   set.generate_url(nil, {:controller => 'c', :action => 'a'}) == '/c/a' => true
      #   set.generate_url(:test_route, {:controller => 'c', :action => 'a'}) == '/c/a' => true
      #   set.generate_url(route.primary_path, {:controller => 'c', :action => 'a'}) == '/c/a' => true
      def generate(routing_lookup, params = nil, options = nil)
        delimiter = options && options.key?(:delimiter) ? options.delete(:delimiter) : @usher.delimiters.first

        path = case routing_lookup
        when Symbol
          route = @usher.named_routes[routing_lookup] 
          params.is_a?(Hash) ? route.find_matching_path(params) : route.paths.first
        when Route
          params.is_a?(Hash) ? routing_lookup.find_matching_path(params) : routing_lookup.paths.first
        when nil
          params.is_a?(Hash) ? @usher.path_for_options(params) : raise
        when Route::Path
          routing_lookup
        end

        raise UnrecognizedException.new unless path

        params = Array(params) if params.is_a?(String)
        if params.is_a?(Array)
          extra_params = params.last.is_a?(Hash) ? params.pop : nil
          params = Hash[*path.dynamic_parts.inject([]){|a, dynamic_part| a.concat([dynamic_part.name, params.shift || raise(MissingParameterException.new)]); a}]
          params.merge!(extra_params) if extra_params
        end

        result = ''
        path.parts.each do |part|
          case part
          when Route::Variable
            value = (params && params.delete(part.name)) || part.default_value || raise(MissingParameterException.new)
            case part.type
            when :*
              value.each_with_index do |current_value, index|
                current_value = current_value.to_s unless current_value.is_a?(String)
                part.valid!(current_value)
                result << current_value
                result << delimiter if index != value.size - 1
              end
            when :':'
              value = value.to_s unless value.is_a?(String)
              part.valid!(value)
              result << value
            end
          else
            result << part
          end
        end
        result = URI.escape(result)

        if params && !params.empty?
          has_query = result[??]
          params.each do |k,v|
            case v
            when Array
              v.each do |v_part|
                result << (has_query ? '&' : has_query = true && '?') << CGI.escape("#{k.to_s}[]") << '=' << CGI.escape(v_part.to_s)
              end
            else
              result << (has_query ? '&' : has_query = true && '?') << CGI.escape(k.to_s) << '=' << CGI.escape(v.to_s)
            end
          end
        end
        result
      end
    end
  end
end