require 'opal'
require 'native'


def p o
  `console.log(#{o.inspect})`
end

module RX
  def self.map
    @map ||= {}
  end
      
  class Styles
    def self.create_view_style opts={}
      `RX.Styles.createViewStyle(#{opts.to_n})`  
    end      
    
    def [] k
      @h[k]
    end
    
    def method_missing m,*o,&b
      return @h[m.to_sym] if @h.has_key?(m.to_sym)
    
      super
    end
    
    def initialize h={}
      @h={}
      merge h
    end
    
    def merge h={}
      h.each_pair do |k,v|
        if !(v.find do |kk,vv| vv.is_a?(Hash) end)
          @h[k] = RX.style(v)
        else
          @h[k] = Styles.new(v)
        end
      end
      
      @h
    end
    
    def delete(k)
      @h.delete(k)
    end    
  end
  
  def self.style o={}
    Styles.create_view_style(o)
  end     
  
  class Component
    Base = `window.RXBase`
    
    module ClassFuncs
      def self.extended klass
      
      end
    end
    
    def self.inherited klass
      klass.extend ClassFuncs
      RX.map[m=klass.to_s.gsub("::",'').to_sym] = klass
      
      RX::Component.class_eval do
        define_method m do |*o, &b|
          this = self
          klass.jsx(*o,&b)
        end
      end 
  
    end
    
    def self.export_name
      to_s.gsub("::", '')
    end
    
    def self.state h=nil
      @default_state ||= {} 
      if h
        h.keys.each do |k| @default_state[k] = h[k] end
      end
      @default_state
    end

    def self.styles h=nil
      (@styles||=Styles.new)
      
      @styles.merge h if h
      
      return @styles
    end
    
    def style
      self.class.styles
    end

    def self.jsx *o, &b
      parent, opts = RX.build_args(*o)
    
      opts[:block] = b
      opts[:opal]  = self
      
      b = nil
      
      self.present(self::Base, opts, parent, &b)
    end
    
    def self.replace_text(children, style_sheet=nil)
      children = [children].flatten

          `var h = {};
          
          if (style_sheet) {
            h = {style: #{style_sheet.text}};
          }` if style_sheet
      
      
      a = []
      children.each do |c|
        next unless c
        
        if c.is_a?(String)
          a << Native(`RX.createElement(RX.Text, h, c)`)
        else
          a << c
        end
      end
      
      a    
    end
    
    def self.build_args *o      
      opts = {}
      
      if o[0].is_a?(RX::Component)
        parent = o.shift
      end
        
      opts = o[-1] if o[-1]
    
      a=[parent,opts]
      
      return a
    end     
    
    def self.events props, &b
      props.keys.find_all do |k| k.to_s =~ /^on\_/ end.each do |k|
        yield k
      end
    end
    
    def self.camel_case str
      a=str.split("_")
      (a[1..-1].map do |q| q.capitalize end.join)
    end
    
    def self.present what, opts={}, parent=nil, &b
      children = b.call if b
      
      style =  opts[:style] || (parent ? parent.style : nil)

      children = replace_text(children, style)  unless what == `RX.Text`
      
      props={}
      
      opts.each_pair do |k,v| props[k]=v end
      props[:style] = opts[:style].container if opts[:style].is_a?(Styles)
      
      e = RX.create_element(what, props, children)
    
      events opts do |k|
        e.on(:"#{camel_case(k).to_s}") {
          opts[k].is_a?(Symbol) ? (parent ? parent.send(opts[k]) : send(opts[k])) : opts[k].call
        } 
      end
      
      e
    end
    
    def props
      Native(`#{@rx}.props`)
    end
    
    attr_reader :rx
    
    def initialize rx
      @rx = rx
      
      `#@rx.state = #{self.class.state.to_n}`
    end
    
    def render
      b = props()[:block]
      children = b.call self if b
      
      Component.replace_text(children, self.style)
    end
    
    def []= k,v
      
      v = v.to_n if v.respond_to?(:to_n)
      
      h = {k=>v}
      
      `#{@rx}.setState(#{h.to_n})`
    end
    
    def [] k
      `#{@rx}.state[#{k}]`
    end
    
    def to_n
      @rx
    end
  end
  
  def self.build_args *o
    Component.build_args(*o)
  end
  
  def self.Text *o, &b
    parent, props = Component.build_args(*o)
    
    Component.present(`RX.Text`, props, parent, &b)
  end

  def self.View *o, &b
    parent, props = build_args(*o)
    
    Component.present(`RX.View`, props, parent, &b)
  end

  def self.Image *o, &b
    parent, props = build_args(*o)
    
    Component.present(`RX.Image`, props, parent, &b)
  end
  
  def self.Link *o, &b
    parent, props = build_args(*o)
    
    Component.present(`RX.Link`, props, parent, &b)
  end  
  
  def self.Button *o, &b
    parent, props = build_args(*o)
  
    if txt=props.delete(:text)
      b = proc do
        txt
      end
    end
  
    Component.present(`RX.Button`, props, parent, &b)
  end  
  
  def self.ScrollView *o, &b
    parent, props = build_args(*o)
    
    Component.present(`RX.ScrollView`, props, parent, &b)
  end  
  
  def self.method_missing(m,*o,&b)
    if c=map[m.to_sym]
      c.jsx(*o,&b)
    end
  end
  
  def self.build &b
    [class_eval(&b)]
  end
  
  class Interval
    attr_reader :id
    def initialize every, start=true, &b
      @window = `window`
      @every  = every
      
      @block = proc do
        if b.call(self)
          
        else
          abort
        end
      end
      
      @stopped = true
      
      start()
    end
    
      # Stop the interval, it will be possible to start it again.
    def stop
      return if stopped?

      `#@window.clearInterval(#@id)`

      @stopped = true
      @id      = nil
    end

    # Start the interval if it has been stopped.
    def start
      raise "the interval has been aborted" if aborted?
      return unless stopped?

      @stopped = false

      @id = `#@window.setInterval(#@block, #@every * 1000)`
    end
    
    def stopped?; @stopped == true end
    
    def abort
      stop
      @abort = true
    end 
    
    def aborted?; @abort == true end
  end
  
  def self.every int, &b
    Interval.new(int, &b)
  end
  
  def self.timeout int, &b
    Interval.new(int) do |i|
      b.call i
      
      false
    end
  end
  
  class Element
    attr_accessor :native
    def initialize what, opts={}, children=[]
      @opts, @what, @children = opts,what,children 
    end
    
    def to_n
      @native ||= (Native(`RX.createElement(#{@what}, #{@opts.to_n}, #{@children.to_n})`)).to_n
    end
    
    def on e, &b
      (@opts||={})[:"on#{e.capitalize}"] = b.to_n
      
      self
    end
  end
  
  def self.create_element what, opts={}, children=[]
    e=Element.new(what, opts, children)  
  end

  def self.app(&b)
    @block = proc do
      class_eval(&b)
    end
    
    `OpalRender =  #{@block}`
  end
end
