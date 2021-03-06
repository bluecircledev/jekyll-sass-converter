require 'spec_helper'

describe(Jekyll::Converters::Scss) do
  let(:site) do
    Jekyll::Site.new(site_configuration)
  end
  let(:content) do
    <<-SCSS
$font-stack: Helvetica, sans-serif;
body {
  font-family: $font-stack;
  font-color: fuschia;
}
SCSS
  end
  let(:css_output) do
    <<-CSS
body {\n  font-family: Helvetica, sans-serif;\n  font-color: fuschia; }
CSS
  end
  let(:invalid_content) do
    <<-SCSS
$font-stack: Helvetica
body {
  font-family: $font-stack;
SCSS
  end

  def compressed(content)
    content.gsub(/\s+/, '').gsub(/;}/, '}') + "\n"
  end

  def converter(overrides = {})
    Jekyll::Converters::Scss.new(site_configuration({"sass" => overrides}))
  end

  context "matching file extensions" do
    it "matches .scss files" do
      expect(converter.matches(".scss")).to be_truthy
    end

    it "does not match .sass files" do
      expect(converter.matches(".sass")).to be_falsey
    end
  end

  context "determining the output file extension" do
    it "always outputs the .css file extension" do
      expect(converter.output_ext(".always-css")).to eql(".css")
    end
  end

  context "when building configurations" do

    it "allow caching in unsafe mode" do
      expect(converter.sass_configs[:cache]).to be_truthy
    end

    it "set the load paths to the _sass dir relative to site source" do
      expect(converter.sass_configs[:load_paths]).to eql([source_dir("_sass")])
    end

    it "allow for other styles" do
      expect(converter({"style" => :compressed}).sass_configs[:style]).to eql(:compressed)
    end

    context "when specifying sass dirs" do
      context "when the sass dir exists" do
        it "allow the user to specify a different sass dir" do
          FileUtils.mkdir(source_dir('_scss'))
          expect(converter({"sass_dir" => "_scss"}).sass_configs[:load_paths]).to eql([source_dir("_scss")])
          FileUtils.rmdir(source_dir('_scss'))
        end

        it "not allow sass_dirs outside of site source" do
          expect(
            converter({"sass_dir" => "/etc/passwd"}).sass_dir_relative_to_site_source
          ).to eql(source_dir("etc/passwd"))
        end
      end
    end

    context "in safe mode" do
      let(:verter) {
        Jekyll::Converters::Scss.new(site.config.merge({
          "sass" => {},
          "safe" => true
        }))
      }

      it "does not allow caching" do
        expect(verter.sass_configs[:cache]).to be_falsey
      end

      it "forces load_paths to be just the local load path" do
        expect(verter.sass_configs[:load_paths]).to eql([source_dir("_sass")])
      end

      it "allows the user to specify the style" do
        allow(verter).to receive(:sass_style).and_return(:compressed)
        expect(verter.sass_configs[:style]).to eql(:compressed)
      end

      it "defaults style to :compact" do
        expect(verter.sass_configs[:style]).to eql(:compact)
      end

      it "only contains :syntax, :cache, :style, and :load_paths keys" do
        expect(verter.sass_configs.keys).to eql([:load_paths, :syntax, :style, :cache])
      end
    end
  end

  context "converting SCSS" do
    it "produces CSS" do
      expect(converter.convert(content)).to eql(compressed(css_output))
    end

    it "includes the syntax error line in the syntax error message" do
      error_message = 'Invalid CSS after "body ": expected selector or at-rule, was "{" on line 2'
      expect {
        converter.convert(invalid_content)
      }.to raise_error(Jekyll::Converters::Scss::SyntaxError, error_message)
    end
  end

  context "importing partials" do
    let(:test_css_file) { dest_dir("css/main.css") }
    before(:each) { site.process }

    it "outputs the CSS file" do
      expect(File.exist?(test_css_file)).to be_truthy
    end

    it "imports SCSS partial" do
      expect(File.read(test_css_file)).to eql(compressed(".half {\n  width: 50%; }\n"))
    end

    it "uses a compressed style" do
      instance = site.getConverterImpl(Jekyll::Converters::Scss)
      expect(instance.jekyll_sass_configuration).to eql({"style" => :compressed})
      expect(instance.sass_configs[:style]).to eql(:compressed)
    end
  end

  context "importing from external libraries" do
    let(:external_library) { source_dir("bower_components/jquery") }
    let(:verter) { site.getConverterImpl(Jekyll::Converters::Scss) }
    let(:test_css_file) { dest_dir('css', 'main.css') }

    context "unsafe mode" do
      let(:site) do
        Jekyll::Site.new(site_configuration.merge({
          "source" => sass_lib,
          "sass"   => {
            "load_paths" => external_library
          }
        }))
      end
      before(:each) do
        FileUtils.mkdir_p(external_library) unless File.directory?(external_library)
      end
      after(:each) do
        FileUtils.mkdir_p(external_library) unless File.directory?(external_library)
      end

      it "recognizes the new load path" do
        expect(verter.sass_load_paths).to include(external_library)
      end

      it "ensures the sass_dir is still in the load path" do
        expect(verter.sass_load_paths).to include(sass_lib("_sass"))
      end

      it "brings in the grid partial" do
        site.process
        expect(File.read(test_css_file)).to eql("a {\n  color: #999999; }\n")
      end

      context "with the sass_dir specified twice" do
        let(:site) do
          Jekyll::Site.new(site_configuration.merge({
            "source" => sass_lib,
            "sass"   => {
              "load_paths" => [
                external_library,
                sass_lib("_sass")
              ]
            }
          }))
        end

        it "ensures the sass_dir only occurrs once in the load path" do
          expect(verter.sass_load_paths).to eql([external_library, sass_lib("_sass")])
        end
      end
    end

    context "safe mode" do
      let(:site) do
        Jekyll::Site.new(site_configuration.merge({
          "safe"   => true,
          "source" => sass_lib,
          "sass"   => {
            "load_paths" => external_library
          }
        }))
      end

      it "ignores the new load path" do
        expect(verter.sass_load_paths).not_to include(external_library)
      end

      it "ensures the sass_dir is the entire load path" do
        expect(verter.sass_load_paths).to eql([sass_lib("_sass")])
      end
    end

  end

end
