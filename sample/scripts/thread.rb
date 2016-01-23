begin
  java.import("android/widget/TextView")
  java.import "android/widget/Button"
  java.import "android/widget/LinearLayout"

  class Updater
    attr_reader :thread
    def initialize
      @thread = Thread.new do
        begin  
          i = -1       
          java.import "java/lang/Thread"
          loop do 
            p [:THREAD, Java::Lang::Thread.currentThread().getId()]
            handler.emit :post, i+=1
            sleep 0.04
          end
        rescue=>e
          p [:THREAD_ERROR, e]
        end
      end
    end
  end  
  
  param = Android::Widget::LinearLayout::LayoutParams.new(:match_parent, :match_parent, 3.0);
  
  ll = Android::Widget::LinearLayout.new(activity)
  ll.setOrientation :vertical
  
  tv = Android::Widget::TextView.new(activity)
  
  b=Android::Widget::Button.new(activity)
  b.setText "Click Me!"  
  a = Java::Lang::Thread.currentThread().getId()
  b.setOnClickListener() do |v|
    p [:THREAD, Java::Lang::Thread.currentThread().getId()]
    p [:THREAD, a]
    tst = toast "ouch!"
  end

  ll.addView(tv, param)
  ll.addView(b)
  
  activity.setContentView ll
  
  handler.on :foo  do |*o|
    tv.setText "Thread Looped: #{o[0]} times!"
  end
  
  Updater.new()
rescue => e
  p "MAIN: Error - #{e} :: #{$r}"
end
