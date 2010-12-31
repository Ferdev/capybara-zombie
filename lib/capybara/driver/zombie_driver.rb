class Capybara::Driver::Zombie < Capybara::Driver::Base
  class Node < Capybara::Driver::Node
  end
end

Capybara.register_driver :zombie do |app|
  Capybara::Driver::Zombie.new(app)
end
