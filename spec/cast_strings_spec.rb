require 'spec_helper'

class Exception
  alias :_message :message
  def message
    @message ||= _message
  end
  def message= msg
    @message = msg
  end
end

describe "Cassava::Document" do
  attr_accessor :d
  before do
    self.d = Cassava::Document.new(:name => 'test', :columns => [ :nil, :string, :integer, :float ])
    rows = <<"END".split("\n").map{|r| r.strip.split(/,\s+/).map{|x| x == 'nil' ? nil : x }}
       nil, nil, nil, nil
       nil, string, nil, nil
       nil, +, nil, nil
       nil, -, nil, nil
       nil, 234+, nil, nil
       nil, 1234ws, nil, nil
       nil, nil, 1234, nil
       nil, nil, +1234, nil
       nil, nil, -1234, nil
       nil, nil, nil, .2
       nil, nil, nil, -1.2
       nil, nil, nil, -2.
       nil, nil, nil, 2e10
       nil, nil, nil, 1e1
       nil, nil, nil, 2E-2
       nil, nil, nil, 3E+3
       nil, nil, nil, nil, 1234, nil
       nil, nil, nil, nil, 12341231234523452345345234, nil
       nil, nil, nil, nil, nil, 1234
       nil, nil, nil, nil, nil, 123412348102394812934
       nil, nil, nil, nil, nil, 1234.2342
END
    d.append_rows! rows
    d.cast_strings!
  end

  def each_row
    i = 0
    d.rows.each do | r |
      begin
        yield r
      rescue ::Exception => exc
        exc.message = "in row #{i} : #{r.inspect} : #{exc.message}"
        raise exc
      end
      i += 1
    end
  end

  context "#cast_strings!" do
    it "should not touch nil columns" do
      each_row do | r |
        r[0].should == nil
      end
    end
    it "should not touch string only columns" do
      each_row do | r |
        next if r[1].nil?
        r[1].class.should == String
      end
    end
    it "should coerce integer columns" do
      each_row do | r |
        next if r[2].nil?
        r[2].is_a?(Integer).should == true
      end
    end
    it "should coerce float columns" do
      each_row do | r |
        next if r[3].nil?
        r[3].is_a?(Float).should == true
      end
    end
  end

  context "#infer_types!" do
    it "should infer nil for all nils" do
      d.column_types[0].should == nil
    end
    it "should infer String for String" do
      d.column_types[1].should == String
    end
    it "should infer Fixum for Fixnum" do
      d.column_types[2].should == Fixnum
    end
    it "should infer Float for all Float" do
      d.column_types[3].should == Float
    end
    it "should infer Integer for Fixnum and Bignum" do
      d.column_types[4].should == Integer
    end
    it "should infer Numeric for Fixnum, Bignum, Float" do
      d.column_types[4].should == Integer
    end
  end
end
