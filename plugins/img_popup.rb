# This plugin uses Mini Magick to generate a scaled down, inline image (really,
# it just uses Mini Magick to calculate the appropriate size; the real image is
# scaled by the browser), and then generates a popup with the full-size image,
# using jQuery UI Dialog. The printer-friendly view just uses the full-size
# image.
#
# This plugin is useful when you have to display an image that's too wide for
# the blog.
#
# Usage:
#
# imgpopup /relative/path/to/image nn% [title]
#
# The image path is relative to "source". The second parameter is the scale
# percentage. The third parameter is a title for the popup.
#
# Example:
#
# {% imgpopup /images/my-big-image.png 50% Check this out %}
#
# You can see this plugin in use here:
#
# http://brizzled.clapper.org/blog/2011/10/23/the-candidates/
#
# Copyright (c) 2012 Brian M. Clapper <bmc@clapper.org>
#
# Released under a standard BSD license.

require 'mini_magick'
require 'rubygems'
require 'erubis'
require 'fileutils'
require './plugins/raw'

module Jekyll

  class ImgPopup < Liquid::Tag
    include TemplateWrapper

    @@id = 0

    TEMPLATE = %{
    <div class="imgpopup screen">
      <div class="caption">Click the image for a larger view.</div>
      <a href='#' style="text-decoration: none" id="image-<%= id %>">
        <img src="<%= image %>"
             width="<%= scaled_width %>" height="<%= scaled_height %>"
             alt="Click me."/>
      </a>
      <div id="image-dialog-<%= id %>" style="display:none">
        <img src="<%= image %>"
             width="<%= full_width %>" height="<%= full_height %>"/>
        <br clear="all"/>
      </div>
    </div>
    <script type="text/javascript">
      $(document).ready(function() {
        $("#image-dialog-<%= id %>").dialog({
          autoOpen:  false,
          modal:     true,
          draggable: false,
          minWidth:  <%= full_width + 40 %>,
          minHeight: <%= full_height + 40 %>,
          <% if title -%>
          title:     "<%= title %>",
          <% end -%>
          show:      'scale',
          hide:      'scale'
        });

        $("#image-<%= id %>").click(function() {
          $("#image-dialog-<%= id %>").dialog('open');
        });
      });
    </script>
    <div class="illustration" print">
      <img src="<%= image %>" width="<%= full_width %>" height="<%= full_height %>"/>
    </div>
    }

    def initialize(tag_name, markup, tokens)
      args = markup.strip.split(/\s+/, 3)
      raise "Usage: imgpopup path nn% [title]" unless [2, 3].include? args.length

      @path = args[0]
      if args[1] =~ /^(\d+)%$/
        @percent = $1
      else
        raise "Percent #{args[1]} is not of the form 'nn%'"
      end
      @template = Erubis::Eruby.new(TEMPLATE)
      @title = args[2]
      super
    end

    def render(context)
      source = Pathname.new(context.registers[:site].source).expand_path

      # Calculate the full path to the source image.
      image_path = source + @path.sub(%r{^/}, '')

      @@id += 1
      vars = {
        'id'      => @@id.to_s,
        'image'   => @path,
        'title'   => @title
      } 

      # Open the source image, and scale it accordingly.
      image = MiniMagick::Image.open(image_path)
      vars['full_width'] = image[:width]
      vars['full_height'] = image[:height]
      image.resize "#{@percent}%"
      vars['scaled_width'] = image[:width]
      vars['scaled_height'] = image[:height]

      safe_wrap(@template.result(vars))
    end
  end
end

Liquid::Template.register_tag('imgpopup', Jekyll::ImgPopup)
