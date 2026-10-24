# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe AccountsPayable::SatStylesheetLoader do
  def with_stylesheets(root:, dependency: nil)
    Dir.mktmpdir('sat-stylesheets') do |directory|
      path = Pathname.new(directory).join('main.xslt')
      File.write(path, root)
      if dependency
        partial = path.dirname.join('xslt/example.xslt')
        FileUtils.mkdir_p(partial.dirname)
        File.write(partial, dependency)
      end
      yield(path)
    end
  end

  let(:include_tag) { '<xsl:include href="xslt/example.xslt"/>' }
  let(:valid_dependency) do
    <<~XSLT
      <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
        <xsl:template name="included">accepted</xsl:template>
      </xsl:stylesheet>
    XSLT
  end

  it 'preserves a stylesheet without local dependencies' do
    with_stylesheets(root: '<xsl:stylesheet/>') do |path|
      expect(described_class.call(stylesheet: path)).to eq('<xsl:stylesheet/>')
    end
  end

  it 'replaces an included local stylesheet with the full template content' do
    with_stylesheets(root: include_tag, dependency: valid_dependency) do |path|
      text = described_class.call(stylesheet: path)
      expect(text).to include('name="included"')
      expect(text).not_to include('xsl:include')
    end
  end

  it 'fails closed if the requested local dependency is absent' do
    with_stylesheets(root: include_tag) do |path|
      expect { described_class.call(stylesheet: path) }
        .to raise_error(ArgumentError, /Missing offline SAT stylesheet dependency/)
    end
  end

  it 'does not accept a parent directory traversal' do
    with_stylesheets(root: '<xsl:include href="xslt/../secrets.xslt"/>') do |path|
      expect { described_class.call(stylesheet: path) }
        .to raise_error(ArgumentError, /Unsafe CFDI stylesheet dependency/)
    end
  end

  it 'does not accept an absolute or remote dependency' do
    ['/tmp/external.xslt', 'https://example.org/evil.xslt'].each do |untrusted|
      with_stylesheets(root: %(<xsl:include href="#{untrusted}"/>)) do |path|
        expect { described_class.call(stylesheet: path) }
          .to raise_error(ArgumentError, /Unsafe CFDI stylesheet dependency/)
      end
    end
  end

  it 'rejects a dependency that has no stylesheet root' do
    with_stylesheets(root: include_tag, dependency: 'not a stylesheet') do |path|
      expect { described_class.call(stylesheet: path) }
        .to raise_error(ArgumentError, /Invalid offline SAT stylesheet dependency/)
    end
  end

  it 'rejects an unclosed stylesheet dependency' do
    with_stylesheets(root: include_tag,
                     dependency: '<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform">') do |path|
      expect { described_class.call(stylesheet: path) }
        .to raise_error(ArgumentError, /Invalid offline SAT stylesheet dependency/)
    end
  end

  it 'rejects transitive local includes instead of permitting unsupervised templates' do
    nested = valid_dependency.sub('</xsl:stylesheet>',
                                  '<xsl:include href="untrusted.xslt"/></xsl:stylesheet>')
    with_stylesheets(root: include_tag, dependency: nested) do |path|
      expect { described_class.call(stylesheet: path) }
        .to raise_error(ArgumentError, /Nested SAT stylesheet dependency is not allowed/)
    end
  end
end
