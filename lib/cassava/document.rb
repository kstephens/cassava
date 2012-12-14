require 'csv'

module Cassava
  class Document
    attr_accessor :name, :columns, :column_offset, :offset_column
    attr_accessor :rows

    def initialize opts = nil
      @opts = opts
      @name = opts[:name] or raise ArgumentError, "name not specified"
      @columns = opts[:columns]
      @column_offset = { }
      @offset_column = [ ]
      @ncols = 0
      @rows = [ ]
      @index = [ ]
    end

    def nrows
      @rows.size
    end

    def empty_rows!
      @rows = [ ]
      @index.clear
      self
    end

    def append_rows! rows
      rows = rows.rows if Document === rows
      rows.map!{ | r | array_to_row(r) }
      @rows.concat(rows)
      rows.each do | r |
        @ncols = r.size if @ncols < r.size
      end
      @index.clear
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

      @columns = @rows.shift unless @columns
      @ncols = @columns.size
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

    def add_column! c
      c = c.to_sym
      unless i = @offset_column[c]
        i = @ncols
        @ncols += 1
        @columns << c
        @offset_column[c] = i
        @column_offset[i] = c
      end
      i
    end

    def index! c
      c = @column_offset[c] if Symbol === c
      unless ind = @index[c] ||= { }
        ind = @index[c] = { }
        @rows.each do | r |
          (ind[r[c]] ||= [ ]) << r
        end
      end
      ind
    end

    def get c, v
      index!(c)[v]
    end

    def emit! document
      CSV.open(document, "wb") do | out |
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

    def cast_strings!
      rows.each do | r |
        r.each do | k, v |
          if String === v
            case v
            when /\A[-+]?\d+\Z/
              v = v.to_i
            when /\A[-+]?[0-9.]+(e[+-]?\d+)?\Z/i
              v = v.to_f
            end
          end
          r[k] = v
        end
      end
    end

    def infer_column_types!
      column_types = [ nil ] * @columns.size
      ancestors_cache = { }
      common_ancestor_cache = { }
      rows.each do | r |
        r.each_with_index do | (k, v), i |
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
              ca = ancestors_cache[ct] ||= ct.ancestors
              va = ancestors_cache[vt] ||= vt.ancestors
              (ca & va).first || Object
            end
          # pp [ :v, v, :ct, ct, :vt, vt, :ca, ca, :va, va, :common_ancestor, common_ancestor ]; $stdin.readline
          # if Value's class is not a specialization of column class.
          ct = common_ancestor
          column_types[i] = ct
        end
      end
      @column_types = column_types
    end
    def column_types
      unless @column_types
        infer_column_types!
      end
      @column_types
    end

    # Format as ASCII table.
    def to_text opts = { }
      gem 'terminal-table'
      require 'terminal-table'

      table = Terminal::Table.new() do | t |
        # t.title = self.name
        s = t.style
        s.border_x = s.border_y = s.border_i = ''
        s.padding_left = 0
        s.padding_right = 1
      end

      # Align numeric columns to the left.
      self.column_types.each_with_index do | t, ci |
        puts "  column #{ci} #{columns[ci]} #{t}"
        if t.ancestors.include?(Numeric)
          table.align_column(ci, :right)
        end
      end

      table << self.columns

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
        end
        table << r
      end

      # Return formatted table.
      table.to_s
    end

    def thousands x, sep = '_'
      x && x.to_s.reverse!.gsub(/(\d{3})/, "\\1#{sep}").reverse!.sub(/^(\D|\A)#{sep}/, '')
    end
  end
end


