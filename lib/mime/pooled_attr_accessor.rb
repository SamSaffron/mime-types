require "mime/value_pool"

module MIME
  module PooledAttrAccessor
  private
    def pooled_attr_accessor(sym, opts = {})
      attr_reader sym
      ivar = :"@#{sym}"
      writer = :"#{sym}="
      define_method writer do |val|
        instance_variable_set(ivar, ValuePool[val])
      end
      private writer if opts[:private_writer]
    end
  end
end
