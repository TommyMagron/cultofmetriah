=begin


* To users of scripts

 * When using scripts obtained through online websites,
  create a new section at this position and paste the script here.
  (Select "Insert" from the pop-up menu in the left list box.)

 * If the creator of the script has any other special instructions, follow them.

 * In general, RPG Maker VX and RPG Maker XP scripts are not compatible, 
   so make sure the resources you have are for RPG Maker VX Ace 
   before you use them.


* To authors of scripts

 * When developing scripts to be distributed to the general public,
  we recommend that you use redefinitions and aliases as much as
  possible, to allow the script to run just by pasting it in this position.


=end

class QWindow < Window

def initialize(x, y, width, height)
super

filename = "Window"
path = "Graphics/System/" + filename
bmp = Bitmap.new(width, height)

self.windowskin = Bitmap.new(path)
self.contents = bmp
self.arrows_visible = false
end

def draw_text(*args)
self.contents.draw_text(*args)
end

def display_text(text)
draw_text(0,-10,width, height, text)
end

end

class QDebug

def initialize
@windows = []

x = 0
y = Graphics.height - 48
height = 45
width = Graphics.width

@windows.push( QWindow.new(0, 0, width/2, height) )
@windows.push( QWindow.new(x+width/2, 0, width/2, height) )
@windows.push( QWindow.new(x, y, width/2, height) )
@windows.push( QWindow.new(x+width/2, y, width/2, height) )
end

def refresh(index, string)
@windows[index].contents.clear
@windows[index].display_text(string)
end

def update(param1, param2)
update_info(@windows[0], param1)
update_info(@windows[1], param2)
update_info(@windows[2], param1)
update_info(@windows[3], param2)
end

def update_info(obj, param)
obj.contents.clear
obj.display_text(param)
end

end