require 'open-uri'
require 'json'

class Convert
  def initialize(branch = 'master')
    @branch = branch
    @files  = get_less_files
  end

  def process
    @files.each do |name|
      unless ['bootstrap.less', 'responsive.less'].include?(name)
        file = open("https://raw.github.com/twitter/bootstrap/#{@branch}/less/#{name}").read

        case name
        when 'mixins.less'
          file = replace_vars(file)
          file = replace_mixin_file(file)
          file = replace_mixins(file)
        when 'utilities.less'
          file = replace_mixin_file(file)
          file = convert(file)
        when 'variables.less'
          file = convert(file)
          file = insert_default_vars(file)
        else
          file = convert(file)
        end

        if name == 'progress-bars.less'
          #file = fix_progress_bar(file)
        end

        save_file(name, file)
      end
    end
  end

private

  # Get the sha of less branch
  def get_tree_sha
    trees = open("https://api.github.com/repos/twitter/bootstrap/git/trees/#{@branch}").read
    trees = JSON.parse trees
    trees['tree'].find{|t| t['path'] == 'less'}['sha']
  end

  def get_less_files
    files = open("https://api.github.com/repos/twitter/bootstrap/git/trees/#{get_tree_sha}").read
    files = JSON.parse files
    files['tree'].select{|f| f['type'] == 'blob' }.map{|f| f['path'] }
  end

  def get_mixins_name
    mixins      = []
    less_mixins = open("https://raw.github.com/twitter/bootstrap/#{@branch}/less/mixins.less").read

    less_mixins.scan(/\.([\w-]+)\(.*\)\s?{?/) do |mixin|
      mixins << mixin
    end

    mixins
  end

  def convert(file)
    file = replace_vars(file)
    file = replace_fonts(file)
    file = replace_font_family(file)
    file = replace_grads(file)
    file = replace_mixins(file)
    file = replace_less_extend(file)
    file = replace_spin(file)
    file = replace_image_urls(file)
    file = replace_image_paths(file)
    file = replace_escaping(file)

    file
  end

  def save_file(name, content)
    name = name.gsub(/\.less/, '')
    f = File.open("stylesheets/compass_twitter_bootstrap/_#{name}.scss", "w+")
    f.write(content)
    f.close
    puts "Converted #{name}\n"
  end

  def replace_mixins(less)
    mixin_pattern = /\.([\w-]+\(.*\))\s?{?/
    less.gsub(mixin_pattern, '@include ctb-\1')
  end

  def replace_mixin_file(less)
    less.gsub(/^\.([\w-]+\(.*\)\s?{?)$/, '@mixin ctb-\1')
  end

  def replace_vars(less)
    less.gsub(/(?!@media)@/, '$')
  end

  def fix_progress_bar(less)
    less = less.gsub(/(\$)(-webkit-keyframes progress-bar-stripes)/, '@\2')
    less = less.gsub(/(\$)(-moz-keyframes)/, '@\2')
    less = less.gsub(/(\$)(keyframes progress-bar-stripes)/, '@\2')
  end

  def replace_fonts(less)
    less.gsub(/#font \> \.([\w-]+)/, '@include font-\1')
  end

  def replace_font_family(less)
    less.gsub(/#font \> #family \> \.([\w-]+)/, '@include font-family-\1')
  end

  def replace_grads(less)
    less.gsub(/#gradient \> \.([\w-]+)/, '@include gradient-\1')
  end

  def replace_less_extend(less)
    less.gsub(/\#(\w+) \> \.([\w-]*)(\(.*\));?/, '@include \1-\2\3;')
  end

  def replace_spin(less)
    less.gsub(/spin/, 'adjust-hue')
  end

  def replace_image_urls(less)
    less.gsub(/background-image: url\("?(.*?)"?\);/) {|s| "background-image: image-url(\"#{$1}\");" }
  end

  def replace_image_paths(less)
    less.gsub('../img/', '')
  end

  def replace_escaping(less)
    less = less.gsub(/\~"([^"]+)"/, '#{\1}') # Get rid of ~ escape
    less.gsub(/(\W)e\("([^\)]+)"\)/) {|s| "#{$1 if $1 != /\s/}#{$2}"} # Get rid of e escape
  end

  def insert_default_vars(scss)
    scss.gsub(/^(\$.+);$/, '\1 !default;')
  end

  def convert_scss(file, folder='')
    sass_files = 'stylesheets_sass'
    system("sass-convert #{file.path} #{sass_files}/#{folder}#{File.basename(file, 'scss')}sass")
  end
end
