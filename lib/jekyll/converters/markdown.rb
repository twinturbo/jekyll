module Jekyll

  class MarkdownConverter < Converter
    safe true

    pygments_prefix "\n"
    pygments_suffix "\n"

    def setup
      return if @setup
      # Set the Markdown interpreter (and Maruku self.config, if necessary)
      case @config['markdown']
        when 'redcarpet'
          begin
            require 'redcarpet'
            # Redcarpet 2.x, converter can be instantiated,
            # and the format of renderer options is in hash, not in array

            # convert extensions array to hash form
            #    [ 'ext_a',        'ext_b',        'ext_c'        ]
            # => { :ext_a => true, :ext_b => true, :ext_c => true }
            redcarpet_extensions = Hash[@config['redcarpet']['extensions'].map { |e| [e.to_sym, true] }]
            redcarpet_render_options = Hash[@config['redcarpet']['render_options'].map { |e| [e.to_sym, true] }] rescue {}

            custom_redcarpet_class = Class.new(Redcarpet::Render::HTML)

            # add SmartyPants module into the class if 'smart' is specified
            if redcarpet_extensions[:smart] == true
              custom_redcarpet_class.class_eval do
                include Redcarpet::Render::SmartyPants
              end
            end

            # TODO: support Renderer options
            @converter = Redcarpet::Markdown.new(custom_redcarpet_class.new(redcarpet_render_options), redcarpet_extensions)
          rescue LoadError
            STDERR.puts 'You are missing a library required for Markdown. Please run:'
            STDERR.puts '  $ [sudo] gem install redcarpet'
            raise FatalException.new("Missing dependency: redcarpet")
          end
        when 'kramdown'
          begin
            require 'kramdown'
          rescue LoadError
            STDERR.puts 'You are missing a library required for Markdown. Please run:'
            STDERR.puts '  $ [sudo] gem install kramdown'
            raise FatalException.new("Missing dependency: kramdown")
          end
        when 'rdiscount'
          begin
            require 'rdiscount'

            # Load rdiscount extensions
            @rdiscount_extensions = @config['rdiscount']['extensions'].map { |e| e.to_sym }
          rescue LoadError
            STDERR.puts 'You are missing a library required for Markdown. Please run:'
            STDERR.puts '  $ [sudo] gem install rdiscount'
            raise FatalException.new("Missing dependency: rdiscount")
          end
        when 'maruku'
          begin
            require 'maruku'

            if @config['maruku']['use_divs']
              require 'maruku/ext/div'
              STDERR.puts 'Maruku: Using extended syntax for div elements.'
            end

            if @config['maruku']['use_tex']
              require 'maruku/ext/math'
              STDERR.puts "Maruku: Using LaTeX extension. Images in `#{@config['maruku']['png_dir']}`."

              # Switch off MathML output
              MaRuKu::Globals[:html_math_output_mathml] = false
              MaRuKu::Globals[:html_math_engine] = 'none'

              # Turn on math to PNG support with blahtex
              # Resulting PNGs stored in `images/latex`
              MaRuKu::Globals[:html_math_output_png] = true
              MaRuKu::Globals[:html_png_engine] =  @config['maruku']['png_engine']
              MaRuKu::Globals[:html_png_dir] = @config['maruku']['png_dir']
              MaRuKu::Globals[:html_png_url] = @config['maruku']['png_url']
            end
          rescue LoadError
            STDERR.puts 'You are missing a library required for Markdown. Please run:'
            STDERR.puts '  $ [sudo] gem install maruku'
            raise FatalException.new("Missing dependency: maruku")
          end
        else
          STDERR.puts "Invalid Markdown processor: #{@config['markdown']}"
          STDERR.puts "  Valid options are [ maruku | rdiscount | kramdown ]"
          raise FatalException.new("Invalid Markdown process: #{@config['markdown']}")
      end
      @setup = true
    end
    
    def matches(ext)
      rgx = '(' + @config['markdown_ext'].gsub(',','|') +')'
      ext =~ Regexp.new(rgx, Regexp::IGNORECASE)
    end

    def output_ext(ext)
      ".html"
    end

    def convert(content)
      setup
      case @config['markdown']
        when 'redcarpet'
          # Redcarpet 2.x, converter can be instantiated
          @converter.render(content)
        when 'kramdown'
          # Check for use of coderay
          if @config['kramdown']['use_coderay']
            Kramdown::Document.new(content, {
              :auto_ids      => @config['kramdown']['auto_ids'],
              :footnote_nr   => @config['kramdown']['footnote_nr'],
              :entity_output => @config['kramdown']['entity_output'],
              :toc_levels    => @config['kramdown']['toc_levels'],
              :smart_quotes  => @config['kramdown']['smart_quotes'],

              :coderay_wrap               => @config['kramdown']['coderay']['coderay_wrap'],
              :coderay_line_numbers       => @config['kramdown']['coderay']['coderay_line_numbers'],
              :coderay_line_number_start  => @config['kramdown']['coderay']['coderay_line_number_start'],
              :coderay_tab_width          => @config['kramdown']['coderay']['coderay_tab_width'],
              :coderay_bold_every         => @config['kramdown']['coderay']['coderay_bold_every'],
              :coderay_css                => @config['kramdown']['coderay']['coderay_css']
            }).to_html
          else
            # not using coderay
            Kramdown::Document.new(content, {
              :auto_ids      => @config['kramdown']['auto_ids'],
              :footnote_nr   => @config['kramdown']['footnote_nr'],
              :entity_output => @config['kramdown']['entity_output'],
              :toc_levels    => @config['kramdown']['toc_levels'],
              :smart_quotes  => @config['kramdown']['smart_quotes']
            }).to_html
          end
        when 'rdiscount'
          rd = RDiscount.new(content, *@rdiscount_extensions)
          html = rd.to_html
          if rd.generate_toc and html.include?(@config['rdiscount']['toc_token'])
            html.gsub!(@config['rdiscount']['toc_token'], rd.toc_content)
          end
          html
        when 'maruku'
          Maruku.new(content).to_html
      end
    end
  end

end
