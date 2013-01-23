require 'spec_helper'

ActiveRecord::Schema.define(:version => 1) do
  create_table :companies, :force => true do |t|
    t.column :name, :string
  end

  create_table :users, :force => true do |t|
    t.column :name, :string
    t.column :company_id, :integer
  end


  create_table :tenants, :force => true do |t|
    t.column :name, :string
  end

  create_table :items, :force => true do |t|
    t.column :name, :string
    t.column :tenant_id, :integer
  end

  create_table :bookkeepers, :force => true do |t|
    t.column :name, :string
  end

  create_table :books, :force => true do |t|
    t.column :name, :string
    t.column :company_id, :integer
    t.column :bookkeeper_id, :integer
  end
end

class Company < ActiveRecord::Base
  has_many :users
  has_many :books
  has_multitenant
end
class User < ActiveRecord::Base
  belongs_to :company
  belongs_to_multitenant :company
end

class Tenant < ActiveRecord::Base
  has_many :items
  has_multitenant
end
class Item < ActiveRecord::Base
  belongs_to :tenant
  belongs_to_multitenant
end

class Bookkeeper < ActiveRecord::Base
  has_many :books
  has_multitenant
end
class Book < ActiveRecord::Base
  belongs_to :company
  belongs_to_multitenant :company
  belongs_to :bookkeeper
  belongs_to_multitenant :bookkeeper
end

describe Multitenant do
  after do 
    Company.current_tenant = nil
    Tenant.current_tenant = nil
  end

  describe 'Company.current_tenant' do
    before { Company.current_tenant = :foo }
    it { Company.current_tenant == :foo }
  end

  describe 'Company.with_tenant block' do
    before do
      @executed = false
      Company.with_tenant :foo do
        Company.current_tenant.should == :foo
        @executed = true
      end
    end
    it 'clears current_tenant after block runs' do
      Company.current_tenant.should == nil
    end
    it 'yields the block' do
      @executed.should == true
    end    
  end

  describe 'Company.with_tenant block that raises error' do
    before do
      @executed = false
      lambda {
        Company.with_tenant :foo do
          @executed = true
          raise 'expected error'
        end
      }.should raise_error('expected error')
    end
    it 'clears current_tenant after block runs' do
      Company.current_tenant.should == nil
    end
    it 'yields the block' do
      @executed.should == true
    end    
  end

  describe 'User.all when current_tenant is set' do
    before do
      @company = Company.create!(:name => 'foo')
      @company2 = Company.create!(:name => 'bar')

      @user = @company.users.create! :name => 'bob'
      @user2 = @company2.users.create! :name => 'tim'
      Company.with_tenant @company do
        @users = User.all
      end
    end
    it { @users.length.should == 1 }
    it { @users.should == [@user] }
  end

  describe 'Item.all when current_tenant is set' do
    before do
      @tenant = Tenant.create!(:name => 'foo')
      @tenant2 = Tenant.create!(:name => 'bar')

      @item = @tenant.items.create! :name => 'baz'
      @item2 = @tenant2.items.create! :name => 'booz'
      Tenant.with_tenant @tenant do
        @items = Item.all
      end
    end
    it { @items.length.should == 1 }
    it { @items.should == [@item] }
  end


  describe 'creating new object when current_tenant is set' do
    before do
      @company = Company.create! :name => 'foo'
      Company.with_tenant @company do
        @user = User.create! :name => 'jimmy'
      end
    end
    it 'should auto_populate the company' do
      @user.company_id.should == @company.id
    end
  end

  describe 'Book.all when multiple current_tenant is set' do
    before do
      @foo = Company.create!(:name => 'foo')
      @bar = Company.create!(:name => 'bar')

      @pedro = Bookkeeper.create!(:name => 'pedro')
      @maria = Bookkeeper.create!(:name => 'maria')

      @book = @foo.books.create! :bookkeeper => @pedro
      @book2 = @maria.books.create! :company => @bar
      @book3 = @foo.books.create! :bookkeeper => @maria
      @book4 = @pedro.books.create! :company => @bar
      
    end
    it "should return 1 if both are set" do
      Company.with_tenant @foo do
        Bookkeeper.with_tenant @maria do
          @books = Book.all
        end
      end
      @books.length.should == 1
      @books.should == [@book3]
    end
    it "should return 2 if only company are set" do
      Company.with_tenant @foo do
        @books = Book.order("id").all
      end
      @books.length.should == 2
      @books.should == [@book, @book3]
    end
    it "should return 2 if only company are set" do
      Bookkeeper.with_tenant @maria do
        @books = Book.order("id").all
      end
      @books.length.should == 2
      @books.should == [@book2, @book3]
    end
  end
end
