require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class SqlParserTest < ActiveSupport::TestCase
  include GoogleDataSource::DataSource

  test "quoting with ticks" do
    result = SqlParser.parse("where `foo bar`=3")
    assert_equal 'foo bar', result.where.left.to_s
  end

  test "quoting with single quotes" do
    result = SqlParser.parse("where bar='foo bar'")
    assert_equal 'foo bar', result.where.right.to_s
  end

  test "allow escaped quotes in qutoed strings" do
    result = SqlParser.parse("where bar='test\\''")
    assert_equal "test'", result.where.right.to_s
  end

  test "allow escaped backslash" do
    result = SqlParser.parse("where bar='te\\\\st'")
    assert_equal "te\\st", result.where.right.to_s
  end

  test "allow escaped backslash as last character" do
    result = SqlParser.parse("where bar='test\\\\'")
    assert_equal "test\\", result.where.right.to_s
  end

  test "parsing of empty single quoted string ('')" do
    result = SqlParser.parse("where foo=''")
    assert_equal "", result.where.right.to_s
  end

  ###############################
  # Test the simple parser
  ###############################
  test "simple parser" do
    result = SqlParser.simple_parse("select id,name where age = 18 group by attr1, attr2 order by age asc limit 10 offset 5")
    assert_equal ['id', 'name'], result.select
    assert_equal 10, result.limit
    assert_equal 5, result.offset
    assert_equal ['attr1', 'attr2'], result.groupby
    assert_equal ['age', :asc], result.orderby
    assert_equal({'age' => '18'}, result.conditions)
  end

  test "simple order parser should only accept a single ordering" do
    assert_raises GoogleDataSource::DataSource::SimpleSqlException do
      SqlParser.simple_parse("order by name,date")
    end
  end

  test "simple where parser" do
    conditions = SqlParser.simple_parse("where id = 1 and name = `foo bar` and `foo bar` = 123").conditions

    assert_equal '1', conditions['id']
    assert_equal 'foo bar', conditions['name']
    assert_equal '123', conditions['foo bar']
  end

  test "simple where parser should only accept and operators" do
    assert_raises GoogleDataSource::DataSource::SimpleSqlException do
      SqlParser.simple_parse("where id = 1 or name = `foo bar`")
    end
  end

  test "where parser should convert other operators than = to array" do
    conditions = SqlParser.simple_parse("where date > '2010-01-01' and date < '2010-02-01'").conditions
    assert_kind_of Array, conditions['date']
    assert_equal '>', conditions['date'].first.op
    assert_equal '2010-01-01', conditions['date'].first.value
    assert_equal '<', conditions['date'].last.op
    assert_equal '2010-02-01', conditions['date'].last.value
  end

end
