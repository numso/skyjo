defmodule SkyjoWeb.HomeView do
  use SkyjoWeb, :view

  def card_style(i) do
    degrees = 360 / 15 * (i + 2)
    radians = degrees / 180 * :math.pi()
    x = :math.cos(radians)
    y = :math.sin(radians)
    "top:#{250 + x * -150}px;left:#{y * 130 - 55}px;transform:rotate(#{degrees}deg);"
  end
end
