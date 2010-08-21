require 'permissive_field_of_view'

class ShadowMap
  include PermissiveFieldOfView
  def initialize settings
    @settings = settings
    @width = settings.map.width
    @height = settings.map.height
    reset_shadows
  end

  def reset_shadows
    @light_map = Array.new(@settings.map.width) do |x|
      Array.new(@settings.map.height) do |y|
        false
      end
    end
  end

  def blocked? x,y
    return @settings.map[x][y] != :empty
  end

  def light x,y
    @light_map[x][y] = true
  end

  def lit? x,y
    @light_map[x][y]
  end

end
