require 'gdbm'
require 'lru_redux'

class MIME::Index

  MISSING = ""

  def self.build!(path, mime_types)
    new(path).tap{|index|index.build!(mime_types)}
  end

  def initialize(path)
    @path = path
    open
  end

  def build!(mime_types)

    delete
    open

    mime_types.each do |mime_type|
      add(@by_simplified, mime_type.simplified, mime_type)
      mime_type.extensions.each do |ext|
        add(@by_extension,ext,mime_type)
      end
    end
  end

  def[](simplified)
    result = @cache_simplified.getset(simplified) do
      read(@by_simplified,simplified) || MISSING
    end

    result == MISSING ? nil : result
  end

  def find_by_extension(extension)
    result = @cache_extension.getset(extension) do
      read(@by_extension,extension)
    end

    result == MISSING ? nil : result
  end

  def each
    @by_simplified.values.each do |v|
      Marshal.load(v).each do |mime_type|
        yield mime_type
      end
    end
  end

  private

  def delete
    @by_simplified.close
    @by_extension.close
    File.delete(simplified_filename) if File.exists?(simplified_filename)
    File.delete(ext_filename) if File.exists?(ext_filename)
  end

  def open
    @by_simplified = GDBM.new(simplified_filename)
    @by_extension = GDBM.new(ext_filename)

    @cache_simplified = LruRedux::Cache.new(100)
    @cache_extension = LruRedux::Cache.new(100)
  end

  def read(gdbm,key)
    if v = gdbm[key]
      Marshal.load(v)
    end
  end

  def add(gdbm, key, value)
    current = read(gdbm,key) || []
    current << value
    gdbm[key] = Marshal.dump(current)
  end

  def simplified_filename
    File.join(@path, "/simplified.gdbm")
  end

  def ext_filename
    File.join(@path, "/ext.gdbm")
  end

end
