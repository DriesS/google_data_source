require 'test/unit'
require 'rubygems'
require 'active_support'
require 'active_support/test_case'
require 'action_controller'
require 'active_record'
require "#{File.expand_path(File.dirname(__FILE__))}/../init"
require 'mocha'

# Setup Database and Models
ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => ":memory:"
)

def setup_db
  ActiveRecord::Schema.define do
    create_table "items", :force => true do |t|
      t.column "name", :string
      t.column "description", :text
      t.column "number", :integer
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Item < ActiveRecord::Base; end
