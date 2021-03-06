package org.jamruby.ext
import org.jamruby.ext.Util
import org.jamruby.ext.ObjectList
import org.jamruby.ext.RubyObject
import org.jamruby.mruby.State
import org.jamruby.mruby.MRuby
import org.jamruby.mruby.Value
import android.view.View
import android.graphics.Canvas
import android.content.Context

class JamView < View
  def initialize c:Context, r:RubyObject
    super c
    @r = r
  end

  def onDraw canvas
    ol = ObjectList.new
    ol.addObj canvas
      
    r.send "on_draw", ol
  end
  
  def onTouchEvent e
    ol = ObjectList.new
    ol.addObj e
    
    r.send "on_touch_event", ol
    true
  end
end
