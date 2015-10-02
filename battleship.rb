require "active_support/all"

# TODO: Standardize locations, maybe have Location class that can convert
# TODO: Just create all the ships, then place them
class Ship
  TYPES = [
    {name: "Aircraft Carrier", length: 5},
    {name: "Battleship", length: 4},
    {name: "Submarine", length: 3},
    {name: "Destroyer", length: 3},
    {name: "Patrol Boat", length: 2},
  ]
  attr_reader :name, :length

  # length
  def initialize(name:, length:, locations:)
    @name = name
    @length = length
    @locations = locations
    @hits = []
  end

  def in?(location)
    @locations.include?(location)
  end

  def hit?(location)
    @hits.include?(location)
  end

  def hit(location)
    @hits << location
  end

  def dead?
    @hits.count == length
  end

  def alive?
    !dead?
  end
end

class Board
  SIZE = 10

  attr_reader :size, :ships, :attacks

  def initialize(name)
    @name = name
    @ships = []
    @attacks = []
    @size = SIZE
  end

  def add_ship(ship)
    @ships << ship
  end

  def place_ship(attrs, locations)
    ship = Ship.new(**attrs, locations: locations)
    add_ship(ship)
  end

  def attacked?(location)
    @attacks.include?(location)
  end

  def attack(location)
    @attacks << location

    if ship = ships.detect { |s| s.in?(location) }
      ship.hit(location)
    end

    ship
  end

  def alive?
    @ships.any?(&:alive?)
  end

  def state(location, show_ship: true)
    if attacked?(location)
      if ships.any? { |s| s.hit?(location) }
        :hit
      else
        :attacked
      end
    else
      if ship = ships.detect { |s| s.in?(location) }
        if show_ship
          [:ship, ship]
        else
          :open
        end
      else
        :open
      end
    end
  end

  def possible_lasts(location, total_length)
    fc = self.class.from_alpha(location)
    length = total_length - 1

    left = [fc[0] - length, fc[1]]
    right = [fc[0] + length, fc[1]]
    up = [fc[0], fc[1] - length]
    down = [fc[0], fc[1] + length]

    possibles = [left, right, up, down]
    # p :possibles, possibles

    trim = possibles.reject { |lc| lc[0] < 1 || lc[1] < 1 || lc[0] > size || lc[1] > size }
    # p :trim, trim

    collide = trim.reject do |lc|
      locs = self.class.fill(fc, lc).map{|a| self.class.to_alpha(*a)}
      locs.any? do |loc|
        ships.any? do |ship|
          ship.in?(loc)
        end
      end
    end
    # p :collide, collide

    alpha = collide.map { |row, col| self.class.to_alpha(row, col) }
    # p :alpha, alpha
    alpha
  end

  # A1, A5 -> [A1, A2, A3, A4, A5]
  AZ = [nil] + ("A".."Z").to_a
  def self.fill(*points)
    fc, lc = points.sort

    rows = (fc[0]..lc[0]).to_a
    cols = (fc[1]..lc[1]).to_a

    res = []
    rows.each do |row|
      cols.each do |col|
        res << [row, col]
      end
    end
    res
  end

  def self.fill_alpha(first_a, last_a)
    p "fill", first_a, last_a

    fc = from_alpha(first_a)
    lc = from_alpha(last_a)

    p "fill", fc, lc

    fill(fc, lc).map { |row, col| to_alpha(row, col) }
  end

  def self.to_alpha(row, col)
    "#{AZ[row]}#{col}"
  end

  # A1 -> [1, 1]
  # G2 -> [2, 7]
  # rowcol -> [row, col]
  def self.from_alpha(alpha)
    _, row_a, col_a = alpha.match(/(\w)(\d+)/).to_a
    [AZ.index(row_a), col_a.to_i]
  end
end

class Game
  attr_reader :boards, :current_player

  def initialize
    @boards = [
      Board.new("Human"),
      Board.new("AI")
    ]

    @current_player = 1
  end

  def playing?
    @boards.all?(&:alive?)
  end

  def next_player!
    @current_player += 1
    @current_player %= @boards.count
  end
end

class GameUI
  attr_reader :stdin, :human_board, :ai_board

  def initialize(stdin=STDIN)
    $game = @game = Game.new

    @human_board = @game.boards[0]
    @ai_board = @game.boards[1]

    @stdin = stdin
  end

  def start
    print_welcome
    place_human_ships
    place_ai_ships

    while @game.playing?
      @game.next_player!

      if @game.current_player == 0
        print_board(ai_board, show_ship: false)
        print_board(human_board, show_ship: true)
        human_move
      else
        ai_move
      end
    end

    print_end
  end

  def print_welcome
    puts "Welcome to Battleship"
  end

  GLYPHS = {
    attacked: "/",
    hit: "X",
    open: "."
  }
  def print_board(board, show_ship: true)
    print "  "
    puts (1..board.size).to_a.join(" ")

    board.size.times.each do |row|
      print(Board::AZ[row + 1])
      print " "

      board.size.times.each do |col|
        alpha = Board.to_alpha(row + 1, col + 1)
        state, ship = board.state(alpha, show_ship: show_ship)

        if state == :ship
          print(ship.name[0])
        else
          print(GLYPHS[state])
        end
        print " "
      end

      print "\n"
    end
  end

  def place_human_ships
    puts "Please place your ships"
    Ship::TYPES.each do |attrs|
      get_ship(attrs)
    end
  end

  def place_ai_ships
    puts "Placing AI ships"
    Ship::TYPES.each do |attrs|
      name = attrs[:name]
      length = attrs[:length]

      print_board(ai_board)

      p :place_ai_ships, name

      begin
        begin
          bow = [rand(1..ai_board.size), rand(1..ai_board.size)]
          p :place_ai_ships, bow
          bow_a = Board.to_alpha(*bow)
          p :place_ai_ships, bow_a
          state = ai_board.state(bow_a)
          p :state, state
          if state == :ship
            puts "Bow would be on a ship, trying again"
          end
        end while state == :ship

        stern_a = ai_board.possible_lasts(bow_a, length).sample

        puts "#{name} stern_a #{stern_a}"

        unless stern_a
          puts "Couldn't find a good spot, trying again."
        end
      end while stern_a.nil?

      locations = Board.fill_alpha(bow_a, stern_a)
      puts "#{name} locations #{locations}"

      ai_board.place_ship(attrs, locations)
    end

    print_board(ai_board)
  end

  def get_ship(attrs)
    print_board(human_board)

    puts "Please place your #{attrs[:name]} (size #{attrs[:length]})"

    begin
      input_okay = true

      # TODO: What if off the baord?
      # TODO: What if on ship?
      puts "Enter bow of ship (forwardmost point):"
      first_loc = stdin.gets.chomp.upcase

      if human_board.state(first_loc) != :open
        input_okay = false
        puts "There's a ship there, enter another location"
        next
      end

      input_okay = true

      possible_lasts = human_board.possible_lasts(first_loc, attrs[:length])
      if possible_lasts.empty?
        input_okay = false
        puts "Ship can't be placed there, try another location"
      else
        puts "Possible stern positions: #{possible_lasts.join(', ')}"
      end
    end until input_okay

    begin
      input_okay = true
      # TODO(Colin): This can be done in board
      puts "Enter stern of ship:"
      last_loc = stdin.gets.chomp.upcase

      if !possible_lasts.include?(last_loc)
        input_okay = false
        puts "Please enter one of the possible positions: #{possible_lasts.join(', ')}"
      end
    end until input_okay

    locations = Board.fill_alpha(first_loc, last_loc)
    human_board.place_ship(attrs, locations)
  end

  def human_move
    puts "Call your shot:"
    location = stdin.gets.chomp.upcase
    ship = ai_board.attack(location)
    if ship
      puts "Hit. #{ship.name}."
      if ship.dead?
        puts "You sunk their #{ship.name}."
      end
    else
      puts "Miss."
    end
  end

  def ai_move
    puts "Computer is thinking..."

    begin
      shot = [rand(1..ai_board.size), rand(1..ai_board.size)]
      shot_a = Board.to_alpha(*shot)
      state = human_board.state(shot_a, show_ship: false)
    end until state == :open

    puts "Computer> #{shot_a}"
    ship = human_board.attack(shot_a)

    if ship
      puts "Hit. #{ship.name}."
      if ship.dead?
        puts "They sunk your #{ship.name}."
      end
    else
      puts "Miss."
    end
  end

  def print_end
    if @game.current_player == 0
      puts "YOU WON!"
    else
      puts "YOU LOST!"
    end
  end
end

class GameTester
  class StdinStub
    def initialize(tokens)
      @tokens = tokens
    end

    def gets
      value = @tokens.shift

      if value
        puts "stub> #{value}"
      else
        # Switch back to stdin
        value = $stdin.gets
      end

      value
    end

    def <<(value)
      @tokens << value
    end
  end

  def self.test
    script = %w[
      A1
      A5
      B1
      B4
      C1
      C3
      D1
      D3
      E1
      E2
    ]
    # Just start sweeping for ships
    (1..10).each do |row|
      (1..10).each do |col|
        script << "#{Board::AZ[row]}#{col}"
      end
    end
    stdin = StdinStub.new(script)

    game_ui = GameUI.new(stdin)
    game_ui.start
  end
end

if ARGV[0] == "test"
  GameTester.test
else
  GameUI.new.start
end
