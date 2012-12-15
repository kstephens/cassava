require 'rubygems'
require 'cassava/document'
$DEBUG = true
module Cassava
  class Main
    attr_accessor :progname
    attr_accessor :args, :cmd, :opts, :exit_code
    attr_accessor :result, :output
    attr_accessor :by

    def initialize args = nil
      @progname = File.basename($0)
      @args = (args || ARGV).dup
      @opts = { }
      @exit_code = 0
      @output = "/dev/stdout"
      @debug = true
    end

    def run!
      cmds = [ ]
      last_arg = nil

      cmd = [ ]
      args = @args.dup
      while arg = args.shift
        if arg == '-'
          if last_arg
            cmd << last_arg
            last_arg = nil
          end
          last_arg = '--result'
          cmds << cmd
          cmd = [ ]
        else
          cmd << arg
        end
      end
      if last_arg
        cmd << last_arg
        last_arg = nil
      end
      cmds << cmd
      pp cmds

      # Run each command:
      cmds.each do | cmd |
        @args = cmd.dup
        next_cmd!
      end

      result.emit!(@output) if result
      self
    rescue ::Exception => exc
      $stderr.puts "#{progname}: ERROR: #{exc.inspect}"
      $stderr.puts "  #{exc.backtrace * "\n  "}" if @debug || $DEBUG
      @exit_code = 1
      self
    end

    def next_cmd!
      @cmd = @args.shift
      sel = :"_#{cmd}!"
      raise ArgumentError, "Invalid command: #{cmd.inspect}" unless respond_to?(sel)
      send(sel)
    end

    def next_document!
      doc = nil
      opts = { }
      until args.empty?
        case arg = args.shift
        when '-kv'
          k = args.shift.to_sym
          v = args.shift
          @key_vals[k] = v
        when '--result'
          doc = @result
          break
        when '-by'
          self.by = args.shift.split(/\s*,\s*|\s+/)
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
        result.append_rows!(other)
      end
    end

    def _select!
      @key_vals = { }
      @result = next_document!
      @result.coerce_to_strings!
      @key_vals.each do | col, val |
        new_result = @result.dup
        new_result.empty_rows!
        found_rows = result.get(col, val)
        puts "  #{col}=#{val} => #{found_rows.size} rows"
        new_result.append_rows!(found_rows)
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

    def _sort!
      @result = next_document!
      by = self.by || args
      by.map! { | c | c.to_sym }
      @result.sort!(by)
      @result
    end

    def _format!
      rows = @result.to_text
      $stderr.puts rows
      rows = rows.split("\n").map{|r| { :_ => r}}
      require 'pp'; rows
      @result = Cassava::Document.new(:name => "#{@result.name}->format", :columns => [ :_ ], :rows => rows)
      @result
    end
  end
end
