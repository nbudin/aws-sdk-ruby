module AwsSdkCodeGenerator
  module Generators
    class SyntaxExample < Dsl::Docstring

      include Helper

      def initialize(struct_shape:, api:, indent: '')
        @indent = indent
        @api = api
        @struct_shape = struct_shape
        @recursive_shapes = compute_recursive_shapes(@shape)
      end

      def format
        if @struct_shape && @struct_shape['members'].length > 0
          @indent + struct(@struct_shape, @indent, [])
        else
          ''
        end
      end

      private

      def ref_value(ref, i, visited)
        if visited.include?(ref['shape'])
          return "{\n#{i}  # recursive #{ref['shape']}\n#{i}}"
        else
          visited  = visited + [ref['shape']]
        end

        s = shape(ref)
        case s['type']
        when 'structure'
          if ref['shape'] == 'AttributeValue'
            '"value"'
          else
            struct(s, i, visited)
          end

        when 'blob'
          if ref['streaming']
            'source_file'
          else
            '"data"'
          end

        when 'list' then list(s, i, visited)
        when 'map' then map(s, i, visited)
        when 'boolean' then "false"
        when 'integer', 'long' then '1'
        when 'float', 'double' then '1.0'
        when 'byte' then '97'
        when 'character' then '"a"'
        when 'string' then string(ref)
        when 'timestamp' then 'Time.now'
        else raise "unsupported shape #{s['type'].inspect}"
        end
      end

      def struct(struct_shape, i, visited)
        lines = ['{']
        struct_shape['members'].each_pair do |member_name, member_ref|
          lines << struct_member(struct_shape, member_name, member_ref, i, visited)
        end
        lines << "#{i}}"
        lines.join("\n")
      end

      def struct_member(struct, member_name, member_ref, i, visited)
        entry = "#{i}  #{underscore(member_name)}: #{ref_value(member_ref, i + '  ', visited)},"
        required = (struct['required'] || []).include?(member_name)
        apply_comments(member_ref, entry, required: required)
      end

      def list(list_shape, i, visited)
        member_ref = list_shape['member']
        if complex?(member_ref)
          complex_list(member_ref, i, visited)
        else
          scalar_list(member_ref, i, visited)
        end
      end

      def scalar_list(member_ref, i, visited)
        "[#{ref_value(member_ref, i, visited)}]"
      end

      def complex_list(member_ref, i, visited)
        "[\n#{i}  #{ref_value(member_ref, i + '  ', visited)},\n#{i}]"
      end

      def map(map_shape, i, visited)
        key = string(map_shape['key'])
        value = ref_value(map_shape['value'], i + '  ', visited)
        "{\n#{i}  #{key} => #{value},#{comments(map_shape['value'], false)}\n#{i}}"
      end

      def string(ref)
        string_shape = shape(ref)
        if string_shape['enum']
          string_shape['enum'].first.inspect
        else ref['shape']
          ref['shape'].inspect
        end
      end

      def apply_comments(ref, text, required:)
        lines = text.lines.to_a
        if lines[0].match(/\n$/)
          lines[0] = lines[0].sub(/\n$/, comments(ref, required) + "\n")
        else
          lines[0] += comments(ref, required)
        end
        lines.join
      end

      def comments(ref, required)
        comments = []
        if ref[:response_target]
          comments << 'where to write response data, file path, or IO object'
        end
        if ref[:streaming]
          comments << 'file/IO object, or string data'
        end
        if required
          comments << 'required'
        end
        if enum = enum_values(ref)
          comments << "accepts #{enum.to_a.join(', ')}"
        end
        if ddb_av?(ref)
          comments << 'value <Hash,Array,String,Numeric,Boolean,IO,Set,nil>'
        end
        comments == [] ? '' : " # #{comments.join(', ')}"
      end

      def recursive?(ref)
        @recursive_shapes.include?(ref['shape'])
      end

      def enum_values(ref)
        s = shape(ref)
        case s['type']
        when 'list' then enum_values(s['member'])
        when 'string' then s['enum']
        else nil
        end
      end

      def complex?(ref)
        s = shape(ref)
        if s['type'] == 'structure'
          !ddb_av?(ref)
        else
          s['type'] == 'list' || s['type'] == 'map'
        end
      end

      def ddb_av?(ref)
        s = shape(ref)
        case s['type']
        when 'list' then ddb_av?(s['member'])
        when 'structure' then ref['shape'] == 'AttributeValue'
        else false
        end
      end

    end
  end
end
