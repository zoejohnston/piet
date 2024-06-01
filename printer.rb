# Zoe Johnston

# Requires the Chunky PNG library
# https://rubygems.org/gems/chunky_png
# https://github.com/wvanbergen/chunky_png/wiki

require 'chunky_png'

# Creates a PNG which prints the given input when run 
# Doesn't print ~, prints - instead

class PietPrinter
    # Prompts the user for input and constructs Piet source code that will print the input
    def initialize
        if ARGV.empty?
            puts "error: please provide a filename for your png"
            exit(false)
        end

        filename = ARGV[0]

        print "Enter the text you would like to print: "
        input = STDIN.gets.chomp

        # If the user provides no input, does nothing
        if input.empty?
            exit(false)
        end
        
        png = ChunkyPNG::Image.new(input.length * 6, 30, ChunkyPNG::Color::WHITE)
        hue = 0
        buff = input.bytes

        (0 .. input.length - 1).each do |i| 
            colour(png, hue, i, buff[i]) 
            hue = (hue - 60) % 360
        end

        wrap(png, hue)
        
        png.save(filename + ".png", :interlace => true)
    end

    # Colours a segment of the image corresponding to a character
    def colour(image, hue, index, num)
        if num == 126 then num = 45 end
        light = hue_to_rgba(hue, true)
        dark = hue_to_rgba(hue, false)
        i = 0
        (0 .. 24).each { |y| image[6 * index + 5, y] = dark }
        (0 .. 24).any? do |y| 
            (0 .. 4).any? do |x| 
                image[x + (6 * index), y] = light 
                i += 1
                i >= num
            end
        end
    end

    # Wraps up the rest of the drawing 
    def wrap(image, hue)
        black = ChunkyPNG::Color::BLACK
        light = hue_to_rgba(hue, true)
        dark = hue_to_rgba(hue, false)

        remainder = (image.dimension.width - 3) % 4

        (remainder .. image.dimension.width - 7).step(4) do |offset|
            (0 .. 3).each { |x| image[x + offset, 29] = dark }
            (0 .. 1).each { |y| image[3 + offset, 27 + y] = dark }
            (0 .. 2).each { |y| image[offset, 26 + y] = light }
            (0 .. 2).each { |y| image[2 + offset, 26 + y] = light }
            image[3 + offset, 26] = light
            image[1 + offset, 28] = light
        end

        (26 .. 29).each { |y| image[image.dimension.width - 3, y] = light }
        (25 .. 29).each { |y| image[image.dimension.width - 1, y] = light }
        image[image.dimension.width - 2, 29] = light

        (25 .. 29).each { |y| image[0, y] = black }
        [25, 26, 28, 29].each { |y| image[1, y] = black }
        [25, 29].each { |y| image[2, y] = black }
        [25, 26, 28, 29].each { |y| image[3, y] = black }
        [26, 28].each { |y| image[4, y] = black }
        [[1, 27], [2, 27], [2, 26], [2, 28], [4, 27], [5, 27]].each { |arr| image[arr[0], arr[1]] = light }
        image[3, 27] = dark
    end

    # Converts a hue to a rgba value
    def hue_to_rgba(hue, pastel)
        if pastel 
            case hue
            when 0 then 0xffc0ffff
            when 60 then 0xffc0c0ff
            when 120 then 0xffffc0ff
            when 180 then 0xc0ffc0ff
            when 240 then 0xc0ffffff
            when 300 then 0xc0c0ffff
            end
        else
            case hue
            when 0 then 0xff00ffff
            when 60 then 0xff0000ff
            when 120 then 0xffff00ff
            when 180 then 0x00ff00ff
            when 240 then 0x00ffffff
            when 300 then 0x0000ffff
            end
        end
    end
end

PietPrinter.new()
