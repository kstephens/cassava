require 'csv'

module Cassava
  class Document
    attr_accessor :name, :columns, :column_offset, :offset_column
    attr_accessor :rows
    attr_accessor :debug

    def initialize opts = nil
      @opts = opts
      @name = opts[:name] or raise ArgumentError, "name not specified"
      @rows = [ ]
      @index = { }
      self.columns = opts[:columns] || [ ]
      if x = opts[:rows]
        append_row! x
      end
    end

    def columns= x
      @columns = x
      update_columns!
    end

    def update_columns!
      @ncols = @columns.size
      @column_offset = { }
      @offset_column = [ ]
      i = -1
      @columns.map! do | c |
        i += 1
        c = c.to_s
        next if c.empty?
        c = c.to_sym
        @column_offset[c] = i
        @offset_column[i] = c
        c
      end
      @column_types = nil
      @index.keep_if { | c, h | @column_offset[c] }
      self
    end

    def add_column! c
      c = c.to_sym
      unless i = @column_offset[c]
        i = @columns.size
        @columns << c
        update_columns!
      end
      i
    end

    def to_column_names! a
      a.map! do | x |
        case x
        when Integer
          c = @columns[x]
        when String
          if x == (i = x.to_i).to_s
            c = @columns[i]
          else
            c = x.to_sym
          end
        when Symbol
          c = x
        else
          raise TypeError, "#{x.inspect}"
        end
        raise TypeError, "#{x.inspect} => #{c.inspect}" unless c
        c
      end
      a
    end

    def nrows
      @rows.size
    end

    def empty_rows!
      @rows = [ ]
      @index.clear
      @column_types = nil
      self
    end

    def append_rows! rows
      return self unless rows
      if Document === rows
        rows.columns.each { | c | add_column!(c) }
        rows = rows.rows
      end
      rows.map!{ | r | array_to_row(r) }
      row_i = @rows.size
      @rows.concat(rows)
      rows.each do | r |
        @ncols = r.size if @ncols < r.size
        r[:_row_i] = row_i
        row_i += 1
      end
      @index.clear
      @column_types = nil
      self
    end

    def parse!
      # debugger if $DEBUG
      csv = nil
      if RUBY_VERSION =~ /^1\.8/
        @rows = [ ]
        csv = CSV.open(name, "rb", @opts[:col_sep]) do | r |
          @rows << r
        end
      else
        csv_opts = { }
        csv_opts[:col_sep] = @opts[:col_sep] if @opts[:col_sep]
        csv = CSV.open(name, "rb", csv_opts)
        @rows = csv.read
      end

      @columns = @rows.shift if @columns.empty?
      update_columns!

      row_i = 0
      @rows.map! do | r |
        @ncols = r.size if @ncols < r.size
        h = { :_row_i => (row_i += 1) }
        @column_offset.each do | c, i |
          h[c] = r[i] if c && i
        end
        h
      end
      # debugger
      self
    ensure
      csv.close if csv
    end

    def index! c
      c = @column[c] if Integer === c
      unless ind = @index[c]
        ind = { }
        @rows.each do | r |
          (ind[r[c]] ||= [ ]) << r
        end
        @index[c] = ind
      end
      ind
    end

    def get c, v
      index!(c)[v]
    end

    def emit! file
      out = nil
      case file
      when '/dev/stdout', '/dev/fd/0'
        tmp_file = true
        out = $stdout
      when %r{^/dev/}
        tmp_file = true
      end
      if tmp_file
        tmp_file = "/tmp/cassava-#{$$}.csv"
        # $stderr.puts "  #{file} => #{tmp_file}"
        file = tmp_file
      end

      _emit! file

      if tmp_file
        out ||= File.open(tmp, "w")
        # $stderr.puts "  #{tmp_file} => #{out}"
        out.write(File.read(tmp_file))
      end
    ensure
      File.unlink(tmp_file) if tmp_file
    end

    def _emit! file
      CSV.open(file, "wb") do | out |
        a = @offset_column.map do | c |
          c && c.to_s
        end
        out << a
        @rows.each do | r |
          a = @offset_column.map do | i |
            i && r[i]
          end
          out << a
        end
      end
      self
    end
    alias :emit! :_emit!

    def array_to_row a, columns = nil
      if Array === a
        columns ||= self.columns
        h = { }
        columns.each_with_index do | c, i |
          h[c] = a[i]
        end
        a = h
      end
      a
    end

    def row_to_array r
      unless Array === r
        r = @offset_column.map do | c |
          c && r[c]
        end
      end
      r
    end

    def coerce_to_strings!
      rows.each do | r |
        r.each do | k, v |
          r[k] = v.to_s unless String === v
        end
      end
      self
    end

    def cast_strings rows
      rows.each do | r |
        r.each do | k, v |
          next if v.nil?
          old_v = v
          v = v.to_s
          if String === v
            case v
            when /\A[-+]?\d+\Z/
              v = v.to_i
            when /\A([-+]?([0-9]+\.[0-9]+|\.[0-9]+|[0-9]+\.)(e[-+]?\d+)?|[-+]?\d+e[-+]?\d+)\Z/i
              v = v.to_f
            end
            # puts "old_v = #{old_v.inspect} => #{v.inspect}"
          end
          r[k] = v
        end
      end
      rows
    end

    def cast_strings!
      cast_strings @rows
      @column_types = nil
      self
    end

    def sort! by = nil
      by ||= @columns
      cast_strings!
      # by = by.map { | x | column_offset[x] }
      ct = { }
      columns.each_with_index do | c, i |
        ct[c] = column_types[i]
      end
      @rows.sort! do | a, b |
        r = 0
        by.each do | c |
          av = a[c]
          bv = b[c]
          case
          when av.nil? && bv.nil?
            r = 0
          when av.nil?
            r = -1
          when bv.nil?
            r = 1
          else
            r = (av <=> bv rescue nil) || 0
          end
          break if r != 0
        end
        r
      end
      self
    end

    require 'pp'
    def infer_column_types rows = self.rows
      column_types = [ nil ] * @columns.size
      ancestors_cache = { }
      common_ancestor_cache = { }
      rows.each do | r |
        raise unless Hash === r
        @columns.each_with_index do | k, i |
          v = r[k]
          next if v.nil?
          ct = column_types[i]
          vt = v.class
          if ct.nil?
            column_types[i] = vt
            next
          end
          common_ancestor =
            common_ancestor_cache[[ct, vt]] ||=
            begin
              ca =
                ancestors_cache[ct] ||=
                ct.ancestors.delete_if{|x| x.class == Module}
              va =
                ancestors_cache[vt] ||=
                vt.ancestors.delete_if{|x| x.class == Module}
              (ca & va).first || Object
            end
          if @debug && k == :float
            pp [ :k, k, :v, v, :ct, ct, :vt, vt, :ca, ca, :va, va, :common_ancestor, common_ancestor ]
          end
          # if Value's class is not a specialization of column class.
          ct = common_ancestor
          column_types[i] = ct
        end
      end
      # pp columns.zip(column_types)
      column_types
    end

    def column_types
      unless @column_types
        @column_types ||= infer_column_types
      end
      @column_types
    end

    def clone_rows rows = self.rows
      rows.map { | r | r.dup }
    end

    # Format as ASCII table.
    def to_text opts = { }
      gem 'terminal-table'
      require 'terminal-table'

      table = Terminal::Table.new() do | table |
        # t.title = self.name
        s = table.style
        s.border_x = s.border_y = s.border_i = ''
        # s.border_i = '|'
        s.padding_left = 0
        s.padding_right = 1

        table << self.columns.map{|c| { :value => c.to_s, :alignment => :center }}

        # Convert rows to Arrays and handle nil, etc.
        self.rows.each do | r |
          r = self.row_to_array(r)
          r.map! do | c |
            c = case c
                when nil
                  ''
                when Integer
                  thousands(c)
                else
                  c
                end
            # c = "#{c} |"
          end
          table << r
        end

        # Align numeric columns to the left.
        column_types = infer_column_types(cast_strings(clone_rows))
        column_types.each_with_index do | type, ci |
          if type && type.ancestors.include?(Numeric)
            # puts "  column #{ci} #{columns[ci]} #{t}"
            table.align_column(ci, :right)
          end
        end
      end


      # Return formatted table.
      table.to_s
    end

    def thousands x, sep = '_'
      x && x.to_s.reverse!.gsub(/(\d{3})/, "\\1#{sep}").reverse!.sub(/^(\D|\A)#{sep}/, '')
    end
  end
end


