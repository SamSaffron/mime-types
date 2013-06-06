require 'mime/types'
require 'mime/index'
require 'minitest/autorun'
require 'fileutils'


class TestMIME_Index < MiniTest::Unit::TestCase

  def test_index
    types = MIME::Types.new
    MIME::Types['text/plain'].each{|m| types.add(m)}
    MIME::Types.type_for('a.js').each{|m| types.add(m)}

    path = File.join(File.dirname(__FILE__), 'index')
    FileUtils.mkdir_p(path) unless File.exists?(path)

    MIME::Index.build!(path, types)

    index = MIME::Index.new(path)

    assert_equal(index['text/plain'], MIME::Types['text/plain'])
    assert_equal(index.find_by_extension('js'), MIME::Types.type_for('a.js'))

    i = 0
    index.each{|mime_type| i+=1 }
    assert_equal(i, 4)
  end
end
