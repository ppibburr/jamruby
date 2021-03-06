GC.generational_mode = false

$: = []

def raise *o
  p o
  super
end

def include mod
  self.class.include mod
end

class Module
  def implement mod
    class_eval do
      include mod
    end
  end
end

class ::String
  def jmatch str
    p = JamRuby::NativeWrapper.as(JAVA::Java::Util::Regex::Pattern.compile(str), JAVA::Java::Util::Regex::Pattern)
    m = JamRuby::NativeWrapper.as(p.matcher(self), JAVA::Java::Util::Regex::Matcher);
  end
  
  def rjust i, s
    a = i - self.length
    if a > 0
      return (s*a)+self
    end
    
    return self
  end
  
  def uncapitalize 
    self[0, 1].downcase + self[1..-1]
  end 
  
  def uncapitalize! 
    self.replace self[0, 1].downcase + self[1..-1]
  end   
  
  # removes non ascii characters
  def ascii!(replacement="")
    n = bytes
    
    slice!(0..size)
    
    n.each { |b|
     if b < 33 || b > 127 then
       concat(replacement)
     else
       concat(b.chr)
     end
    }
    
    to_s
  end  
end

class JObject
  def as what
    what.wrap self
  end
  
  def cast class_name = nil
    if !class_name
      n = cast("java.lang.Object").getClass.to_s.split(" ").pop
      cst = cast(n)
    else
      cls = __jam_require__ class_name.split(".").join("/")
      
      if cls.respond_to?(:bridge)
        return cls.bridge.wrap(self)
      end
      
      return JamRuby::NativeWrapper.as self, cls
    end
  rescue => e
    self
  end
end 

class Object  
  # mruby-thread issue
  alias :__is_a__ :"is_a?"
  def is_a?(w)
    if w == ::String or w == "".class
      if __is_a__ w
        return true
      end
      
      w = "".class
    end
    
    __is_a__ w
  end
  
  def send_with_casted_params mname, *o
    o = JamRuby.cast_params *o

    send mname, *o
  rescue => e
    p e
    raise e
  end 
end

class Array
  def use_integers bool
    class << self; self; end.define_method "use_integers?" do
      bool
    end
    
    class << self; self; end.define_method "use_longs?" do
      !bool
    end
  end
  
  def use_longs bool
    class << self; self; end.define_method "use_integers?" do
      !bool
    end
    
    class << self; self; end.define_method "use_longs?" do
      bool
    end    
  end
  
  def use_floats bool 
    class << self; self; end.define_method "use_doubles?" do
      !bool
    end
    
    class << self; self; end.define_method "use_floats?" do
      bool
    end 
  end
  
  def use_doubles bool
    class << self; self; end.define_method "use_doubles?" do
      bool
    end
    
    class << self; self; end.define_method "use_floats?" do
      !bool
    end
  end  
  
  def use_floats?
    true
  end
  
  def use_doubles?
    false
  end 
  
  def use_integers?
    true
  end 
  
  def use_longs?
    false
  end        
  
  def native
    to_array_list.native
  end
  
  def to_object_array
    to_object_list.toArray
  end
  
  def to_array_list
    to_object_list
  end
  
  def to_object_list(*o)
    defaults = {
                :use_double  => use_doubles?, 
                :use_integer => use_integers?,
                :use_float   => use_floats?,
                :use_long    => use_longs?
             }
    
    if !o[0]
      o[0] = defaults
    end
    
    unless o[0].is_a? Hash
      raise "ArgumentError: Hash or none"
    end
    
    opts = o[0]
    
    defaults.each_key do |k|
      opts[k] ||= defaults[k]
    end
    
    ol = Org::Jamruby::Ext::ObjectList.create

    each do |v|
      if v.is_a? Integer
        if opts[:use_integer] == true
          ol.addInt v
        else
          ol.addLng v
        end
      elsif v.is_a? Float
        if opts[:use_double] == true
          ol.addDbl(v)
        else
          ol.addFlt(v)
        end
      elsif v.is_a? String
        ol.addStr v
      elsif v.is_a? JObject
        ol.addObj v
      elsif v.respond_to?(:native)
        ol.addObj v.native
      elsif v.is_a? Array
        ol.addObj v.to_object_array
      else
        ol.addObj v.to_java
      end
    end
    
    ol
  end
  
  private
  def __check_jammed__
    unless __jammed__
      class << self
        def __jammed__
          true
        end
      end
      
      use_integers true
      use_floats   true      
    end  
  end
  
  private
  def __jammed__
    false
  end
end

module JamRuby
  def self.cast_params *o
    o.map do |q|
      if q.is_a?(JObject)
        begin
          if JAVA::Org::Jamruby::Ext::NativeArray.isArray(q)
            next JamRuby::NativeArray.new(q)
          end
        rescue => e
        end
        
        begin
          next q.cast()
        rescue => e
          next q
        end
      end

      next q
    end
  end

  class Proxy
    MAP = {}
    
    def self.for what
      cp = nil
    
      if what.is_a? Class
        if what.ancestors.index(NativeObject)
          cp = what.getName
        elsif what.const_defined?(:CLASS_PATH)
          cp = what::CLASS_PATH
        else
          raise ArgumentError.new("Cannot get java class name from: #{what}")
        end
      elsif what.is_a?(String)
        cp = what
      end
      
      cp = cp.gsub("/", '.')    
    
      cls = MAP[cp]
      if !cls
        cls = Class.new(JamRuby::Proxy)
        cls.set_class_path cp
      end
      
      return cls
    end
    
    def self.set_class_path path
      MAP[@class_path = path] = self
    end
    
    def self.get_class_path
      @class_path
    end
    
    def initialize swallow_method_name = true, &b
      set &b
      
      @proxy=proxy(self.class.get_class_path) do |*o|
        o.shift if swallow_method_name
        o = JamRuby.cast_params *o
        @b.call(*o) if @b
      end
    end
    
    def native
      @proxy
    end
    
    def set &b
      @b = b
    end
  end
  
  class Runnable < Proxy
    set_class_path "java.lang.Runnable"
  end
  
  class OnClickListener < Proxy
    set_class_path "android.view.View$OnClickListener"
  end
  
  class Delegate < Proxy
    def native
      @proxy
    end
    
    def initialize
      super false do |mname, *o|
        send mname, *o
      end
    end
    
    def self.of what
      cp = nil
    
      if what.is_a? Class
        if what.ancestors.index(NativeObject)
          cp = what.getName
        elsif what.const_defined?(:CLASS_PATH)
          cp = what::CLASS_PATH
        else
          raise ArgumentError.new("Cannot get java class name from: #{what}")
        end
      elsif what.is_a?(String)
        cp = what
      end
      
      cp = cp.gsub("/", '.')
      cls = Class.new(self)
      cls.set_class_path cp
      cls.singleton_class.define_method :get_class_path do
        cp
      end 
      return cls
    end
  end
end
