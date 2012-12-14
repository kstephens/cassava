require 'cassava/document'

module Cassava
  class Main
    attr_accessor :progname
    attr_accessor :args, :cmd, :opts, :exit_code
    attr_accessor :result

    def initialize args = nil
      @progname = File.basename($0)
      @args = (args || ARGV).dup
      @opts = { }
      @exit_code = 0
      @output = "/dev/stdout"
    end

    def run!
      @cmd = @args.shift
      sel = :"_#{cmd}!"
    raise ArgumentError, "Invalid command: #{cmd.inspect}" unless respond_to?(sel)
      send(sel)
      result.emit!(@output) if result
      self
    rescue ::Exception => exc
      $stderr.puts "#{progname}: ERROR: #{exc.inspect}"
      $stderr.puts "  #{exc.backtrace * "\n  "}" if $DEBUG
      @exit_code = 1
      self
    end

    def next_document!
      doc = nil
      opts = { }
      until args.empty?
        case arg = args.shift
        when '-o'
          self.output = args.shift
        when '-FS'
          opts[:col_sep] = args.shift
        when '-IGNORE'
          opts[:ignore] = args.shift
        when '-C'
          opts[:columns] = args.shift.split(/\s*,\s*|\s+/)
        else
          opts[:name] = arg
          doc = Document.new(opts)
          doc.parse!
          break
        end
      end
      doc
    end

    def _cat!
      @result = next_document!
      until args.empty?
        other = next_document!
        other.columns.each { | c | result.add_column!(c) }
        result.rows.append(other.rows)
      end
    end

    def _select!
      @result = next_document!
      until args.empty?
        new_result = result.dup
        new_result.empty_rows!
        key = args.shift.to_sym
        val = args.shift
        result.rows.each do | r |
          new_result.append_rows!(left.get(key, val))
        end
        @result = new_result
      end
    end

    def _join!
      @result = next_document!
      until args.empty?
        left_key = args.shift.to_sym
        right_key = args.shift.to_sym
        right = next_document!
        new_result = Document.new
        result.columns.each do | c |
          new_result.add_column!(c)
        end
        right.columns.each do | c |
          new_result.add_columns!(c)
        end
        result.rows.each do | lr |
          rrows = right.get(right_key, lr[left_key])
          unless rrows.empty?
            r = lr.dup
            rrows.each do | rr |
              r.merge(rr)
            end
            new_result.rows << r
          end
        end
        @result = new_result
      end
    end
  end
end
