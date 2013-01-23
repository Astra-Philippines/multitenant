require 'active_record'
require 'active_support'

# Multitenant: making cross tenant data leaks a thing of the past...since 2011
module Multitenant
  class MultitenantException < RuntimeError
  end
  
  module InstanceMethods
  end

  module ClassMethods
    def current_tenant
      Thread.current[self.thread_local]
    end

    def current_tenant=(tenant)
      Thread.current[self.thread_local] = tenant
    end
    # execute a block scoped to the current tenant
    # unsets the current tenant after execution
    def with_tenant(tenant, &block)
      self.current_tenant = tenant
      yield
    ensure
      self.current_tenant = nil
    end
  end

  module ActiveRecordExtensions
    def has_multitenant options = {}
      # Check options
      raise Multitenant::MultitenantException.new("Options for has_multitenant must be in a hash.") unless options.is_a? Hash
      options.each do |key, value|
        unless [:thread_local].include? key
          raise Ancestry::AncestryException.new("Unknown option for has_ancestry: #{key.inspect} => #{value.inspect}.")
        end
      end

      # Include instance methods
      include Multitenant::InstanceMethods

      # Include dynamic class methods
      extend Multitenant::ClassMethods
      
      # Create thread_local accessor and set to option or default
      cattr_accessor :thread_local
      self.thread_local = options[:thread_local] || self.name.underscore.to_sym
    end
    
    # configure the current model to automatically query and populate objects based on the current tenant
    # see Multitenant#current_tenant
    def belongs_to_multitenant(association = :tenant)
      reflection = reflect_on_association association
      before_validation Proc.new {|m|
        return unless reflection.klass.current_tenant
        m.send "#{association}=".to_sym, reflection.klass.current_tenant
      }, :on => :create
      default_scope lambda {
        where({reflection.foreign_key => reflection.klass.current_tenant.id}) if reflection.klass.current_tenant
      }
    end
  end
end
ActiveRecord::Base.extend Multitenant::ActiveRecordExtensions
