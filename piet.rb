# Zoe Johnston

# Requires the Chunky PNG library
# https://rubygems.org/gems/chunky_png
# https://github.com/wvanbergen/chunky_png/wiki

require 'chunky_png'

# Creates a PietEnvironment which keeps track of the stack, current colour block, dp and cc.
# Creates a PietPainting which calculates the codel size and allows the interpreter to work by codel
# instead of by pixel.
# Until the interpreter fails to move to a new colour block 8 times, attempts to move to a new colour block.

class PietInterpreter
    # Initializes an environment for the interpreter and a representation of the provided PNG
    def initialize
        image = read_file

        input = if ARGV.length > 1 and ARGV[1] == "-i"
            print "> "
            STDIN.gets.chomp
        else
            ""
        end

        @env = PietEnvironment.new(input)
        @painting = PietPainting.new(image)
        @failures = 0
        begin 
            until @failures > 7
                navigate
            end
            puts
        rescue PietError => e
            puts "\n" + e.message
        end 
    end

    private

    # Returns an image file or exits if no image file can be retrieved
    def read_file
        if ARGV.empty?
            puts "error: please provide the filename of a PNG file when calling"
            exit(false)
        else
            filename = ARGV[0]

            if not filename.downcase.end_with?(".png")
                ext = filename[filename.rindex(".") .. -1]
                puts "error: " + ext + " files are not supported, please provide a PNG file instead"
                exit(false)
            end

            begin
                image = ChunkyPNG::Image.from_file(filename)
            rescue
                puts "error: file '" + filename + "' not found or unable to be read"
                exit(false)
            end
        end
    end

    # Moves the interpreter to the next colour block
    def navigate
        # Instancing a new PietColourBlock gets the next location to move to, the number of 
        # codels in the current colour block, and the colour of the current colour block.
        current = PietColourBlock.new(@painting, @env)
        location = current.next_block
        num = current.num
        old_colour = current.colour

        colour = @painting.codel(location[0], location[1])

        if colour.nil? or colour.black?
            @failures += 1

            if @failures.even?
                @env.rotate
            else
                @env.toggle
            end
        else
            @failures = 0
            @env.move(location)
            old_colour.evaluate(colour, @env, num) unless old_colour.nil? or colour.white?
        end
    end
end

# Subclassing Exception to allow for spcificity in error handling.
class PietError < Exception
end

# This module defines the stack methods for the PietEnvironment class, as described 
# at https://www.dangermouse.net/esoteric/piet.html

# The only errors which stop program flow and are reported are stack overflows and underflows
module Stack
    def push(value)
        if @stack.length >= PietEnvironment::MAX
            raise PietError, "error: stack overflow"
        end

        @stack.push(value)
    end

    def pop
        if @stack.empty?
            raise PietError, "error: stack underflow"
        end

        @stack.pop
    end

    # Adds the two values at the top of the stack
    def add
        x = pop
        y = pop
        push(x + y)
    end

    def substract
        x = pop
        y = pop
        push(y - x)
    end

    def multiply
        x = pop
        y = pop
        push(x * y)
    end
    
    # Divide an mod are ignored if a divide by 0 is attempted
    def divide
        x = pop
        y = pop
        if x != 0
            push(y / x)
        else
            push(y)
            push(x)
        end
    end

    def mod
        x = pop
        y = pop
        if x != 0 
            push(y % x)
        else
            push(y)
            push(x)
        end
    end

    def not
        if pop == 0
            push(1)
        else 
            push(0)
        end
    end

    def greater
        x = pop
        y = pop
        if y > x
            push(1)
        else 
            push(0)
        end
    end

    def pointer
        x = pop % 4
        if x > 0 then (1 .. x).each { rotate } end
    end

    def switch
        x = pop % 2
        if x > 0 then (1 .. x).each { toggle } end
    end

    def duplicate
        x = pop
        push(x)
        push(x)
    end

    def roll
        num = pop
        depth = pop

        # Ignore the command completely when given negative depth
        if depth < 0
            push(depth)
            push(num)
            return
        end

        # Do nothing when asked to do nothing
        if num == 0 or depth < 2
            return
        end

        # If the depth is larger than the stack length, set the depth to the stack length
        if depth > @stack.length
            depth = @stack.length
        end

        if num > 0
            (1 .. num).each do
                x = pop
                @stack.insert(@stack.length - depth + 1, x)
            end
        else 
            (1 .. -1 * num).each do
                x = @stack.delete_at(@stack.length - depth)
                push(x)
            end
        end
    end

    # Gets a char from input. If there is no char, ignore
    def in_char
        if @input.empty?
            return
        end

        char = @input.bytes[0]

        if @input.length < 2
            @input = ""
        else
            @input = @input[1 .. -1]
        end
        
        push(char)
    end

    # Gets an integer from input. If there is no integer, ignore
    def in_integer
        if @input.empty?
            return
        end

        if @input.match(/^\s\d+.*/)
            @input = @input[1 .. -1]
        end

        i = @input.index(/\D/)

        if i.nil?
            int_str = @input
            @input = ""
        elsif i == 0
            return
        else
            int_str = @input[0 .. i - 1]
            @input = @input[i .. -1]
        end

        push(int_str.to_i)
    end
end

class PietEnvironment
    # Maximum stack length
    MAX = 100

    # Initializes the stack, current location, direction pointer, and codel chooser
    def initialize(input)
        @stack = []
        @input = input

        @x = 0
        @y = 0

        @dp = [1, 0]
        @cc = true
    end

    include Stack

    attr_reader :x, :y

    def move(vector)
        @x = vector[0]
        @y = vector[1]
    end

    def dp
        @dp.clone
    end

    def left?
        @cc
    end

    def rotate
        if @dp[0] == 0
            @dp[0] = -1 * @dp[1]
            @dp[1] = 0
        else 
            @dp[1] = @dp[0]
            @dp[0] = 0
        end
    end

    def toggle
        @cc = ! @cc
    end
end

class PietPainting
    # An instance of PietPainting serves to provide a layer of abstraction between the image file
    # and the rest of the code. This allows us to deal with large codel sizes once, and never again. 
    def initialize(image)
        @image = image
        @width = image.dimension.width
        @height = image.dimension.height
        @size = codel_size(@width, @height)
    end

    attr_reader :image

    def width
        @width / @size
    end

    def height
        @height / @size
    end

    def codel(i, j)
        rgba = rgba(i, j)
        if rgba.nil?
            nil
        else
            PietColour.new(rgba)
        end
    end

    def rgba(i, j)
        if i < 0 or j < 0 or i >= width or j >= height
            nil
        else
            @image[i * @size, j * @size]
        end
    end

    private

    # Determines the codel size
    def codel_size(w, h)
        # Gets an array containing all codel sizes which divide the width and height
        possible_x = (1 .. w).select { |x| w % x == 0}
        possible_y = (1 .. h).select { |y| h % y == 0}
        possible = possible_x & possible_y

        if possible.length == 1
            return possible[0]
        end

        possible = possible.reverse

        # Finds the greatest codel size such that all codels are homogenous in colour
        i = possible.index do |size|
            (0 .. w / size - 1).all? do |x|
                (0 .. h / size - 1).all? do |y|
                    homogenous?(x, y, size)
                end
            end
        end

        possible[i]
    end

    # Looks at the size by size square with its top left corner at (x, y), returns true if
    # the square is homogenous in colour
    def homogenous?(x, y, size)
        colour = @image[x * size, y * size]
        not (0 .. size - 1).any? do |x_offset|
            (0 .. size - 1).any? do |y_offset|
                colour != @image[x * size + x_offset, y * size + y_offset]
            end
        end
    end
end

class PietColourBlock
    # Stores information about the environment's current colour block, including the
    # number of codels in the block, the colour of the block, and the location that the
    # interpreter should move to next
    def initialize(painting, env)
        colour = painting.codel(env.x, env.y)
        rgb = colour.rgba

        if colour.white?
            @next_block = slide(painting, rgb, env)
            @num = nil
            @colour = nil
        else
            simplified = blank(painting)
            # The fill method modifies simplified. After running, simplified will indeed be
            # a simplified representation of the colour block
            @num = fill(painting, simplified, rgb, env.x, env.y)
            edge = furthest_edge(painting, simplified, rgb, env)
            @next_block = furthest_codel(painting, simplified, rgb, edge, env)
            @colour = colour
        end
    end

    attr_reader :num, :next_block, :colour

    private

    # Returns a blank image with pixel dimensions equivalent to the codel dimensions of painting
    def blank(painting)
        width = painting.width
        height = painting.height
        colour = ChunkyPNG::Color.rgba(0, 0, 0, 0)
        ChunkyPNG::Image.new(width, height, colour)
    end

    # Slide in the direction of the DP to the first non-white colour block
    def slide(painting, rgb, env)
        location = [env.x, env.y]
        i = env.dp.index { |x| x != 0}

        while not rgb.nil? and PietColour.white(rgb)
            location[i] += env.dp[i]
            rgb = painting.rgba(location[0], location[1])
        end

        location
    end

    # Fills a region in simplified that corresponds to the indicated colour block in painting
    # Returns a count of how many codels are in the colour block 
    def fill(painting, simplified, rgb, x, y)
        if x < 0 or x >= painting.width or y < 0 or y >= painting.height
            return 0
        end

        if painting.rgba(x, y) == rgb and simplified[x, y] != rgb
            simplified[x, y] = rgb
            ret_1 = fill(painting, simplified, rgb, x + 1, y) + fill(painting, simplified, rgb, x - 1, y)
            ret_2 = fill(painting, simplified, rgb, x, y + 1) + fill(painting, simplified, rgb, x, y - 1)
            return 1 + ret_1 + ret_2 
        end

        return 0
    end

    # Returns the location of the colour block's furthest edge, in the direction of the DP
    def furthest_edge(painting, simplified, rgb, env)
        case env.dp
        when [1, 0]
            edge_helper(env.x, 1) { |i| i >= painting.width or not simplified.column(i).any? { |codel| codel == rgb} }
        when [0, 1]
            edge_helper(env.y, 1) { |i| i >= painting.height or not simplified.row(i).any? { |codel| codel == rgb} }
        when [-1, 0]
            edge_helper(env.x, -1) { |i| i < 0 or not simplified.column(i).any? { |codel| codel == rgb} }
        when [0, -1]
            edge_helper(env.y, -1) { |i| i < 0 or not simplified.row(i).any? { |codel| codel == rgb} }
        end
    end

    def edge_helper(count, incr)
        until yield(count)
            count += incr
        end
        count
    end

    # Returns the location of the chosen codel
    def furthest_codel(painting, simplified, colour, edge, env)
        case env.dp
        when [1, 0]
            column = simplified.column(edge - 1)
            if env.left?
                i = column.index { |codel| codel == colour}
            else
                i = painting.height - 1 - column.reverse.index { |codel| codel == colour}
            end
            [edge, i]
        when [0, 1]
            row = simplified.row(edge - 1)
            if env.left?
                i = painting.width - 1 - row.reverse.index { |codel| codel == colour}
            else
                i = row.index { |codel| codel == colour}
            end
            [i, edge]
        when [-1, 0]
            column = simplified.column(edge + 1)
            if env.left?
                i = painting.height - 1 - column.reverse.index { |codel| codel == colour}
            else
                i = column.index { |codel| codel == colour}
            end
            [edge, i]
        when [0, -1]
            row = simplified.row(edge + 1)
            if env.left?
                i = row.index { |codel| codel == colour}
            else
                i = painting.width - 1 - row.reverse.index { |codel| codel == colour}
            end
            [i, edge]
        end
    end
end

class PietColour 
    # Any non-standard colour and white are treated as white
    def self.white(rgba)
        light = [0xffc0c0ff, 0xffffc0ff, 0xc0ffc0ff, 0xc0ffffff, 0xc0c0ffff, 0xffc0ffff].include?(rgba)
        norm = [0xff0000ff, 0xffff00ff, 0x00ff00ff, 0x00ffffff, 0x0000ffff, 0xff00ffff].include?(rgba)
        dark = [0xc00000ff, 0xc0c000ff, 0x00c000ff, 0x00c0c0ff, 0x0000c0ff, 0xc000c0ff].include?(rgba)

        rgba != ChunkyPNG::Color::BLACK and not (light or norm or dark)
    end

    # Colour conversion formulas from here: https://www.rapidtables.com/convert/color/rgb-to-hsv.html
    def initialize(rgba)
        @rgba = rgba

        r = rgba >> 24
        g = 0xff & (rgba >> 16)
        b = 0xff & (rgba >> 8)

        r = r.to_f / 255
        g = g.to_f / 255
        b = b.to_f / 255

        value = [r, g, b].max

        change = value - [r, g, b].min 
        saturation = if value == 0 then 0 else change / value end

        hue = if change == 0
            0
        elsif value == r
            60 * (((g - b) / change) % 6)
        elsif value == g 
            60 * (((b - r) / change) + 2)
        else 
            60 * (((r - g) / change) + 4)
        end

        @hue = hue.to_i
        @lightness = if value > saturation
            2
        elsif value < saturation
            0
        else
            1
        end
    end

    def black?
        @rgba == ChunkyPNG::Color::BLACK
    end

    # Any non-standard colour and white are treated as white
    def white?
        self.class.white(@rgba)
    end

    attr_accessor :hue, :lightness, :rgba

    def evaluate(other, env, num)
        hue_change = (other.hue - self.hue) % 360
        lightness_change = (self.lightness - other.lightness) % 3
        change = [hue_change, lightness_change]

        case change
        when [0, 1] then env.push(num)
        when [0, 2] then env.pop
        when [60, 0] then env.add
        when [60, 1] then env.substract
        when [60, 2] then env.multiply
        when [120, 0] then env.divide
        when [120, 1] then env.mod
        when [120, 2] then env.not
        when [180, 0] then env.greater
        when [180, 1] then env.pointer
        when [180, 2] then env.switch
        when [240, 0] then env.duplicate
        when [240, 1] then env.roll
        when [240, 2] then env.in_integer
        when [300, 0] then env.in_char
        when [300, 1] then print env.pop.to_s
        when [300, 2] then print env.pop.chr
        end
    end
end

PietInterpreter.new()
