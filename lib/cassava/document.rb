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

    def cast_strings!
      rows.each do | r |
        r.map! do | v |
          if String === v
            case v
            when /\A[-+]?\d+\Z/
              v = v.to_i
            when /\A[-+]?[0-9.]+(e[+-]?\d+)?\Z/i
              v = v.to_f
            end
          end
          v
        end
      end
    end

    def infer_column_types!
      column_types = [ nil ] * @ncols
      ancestors_cache = { }
      rows.each do | r |
        r.each_with_index do | v, i |
          next if v.nil?
          ct = column_types[i]
          vt = v.class
          if ct.nil?
            column_types[i] = vt
            next
          end
          ca = ancestors_cache[ct] ||= ct.ancestors
          va = ancestors_cache[vt] ||= vt.ancestors
          common_ancestor = (ca & va).first || Object
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
  end
end


