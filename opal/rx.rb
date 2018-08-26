require 'opal'
require 'native'


def p o
  if `o.$inspect`
    out = o.inspect
  else
    out = `o.toString()`
  end

  `console.log(#{out.split("\n").map do |l| "OpalRX: #{l}" end.join("\n")})`
end

module RX
    `function OpalRXJsonReq(uri, b) {
    return fetch(uri)
      .then((response) => response.json())
      .then((responseJson) => {
        b({object: responseJson});
      })
      .catch((error) => {
        b({err: error});
      });
    }` 
    
    def self.alert msg, title: "OpalRX -"
      `RX.Alert.show(#{title}, #{msg})`
    end
    
    class JSONRequest
      attr_reader :b, :uri, :response
      def initialize uri, &b
        @uri = uri
        @b = proc do |resp|
        `console.log(#{resp})`
          @response = Hash.new(resp)
          b.call self
        end
        
        `OpalRXJsonReq(#@uri, #@b)`
      end
      
      def error
        @response[:error]
      end
      
      def error?
        !!error
      end
      
      def object
        @response[:object]
      end
    end
    
  def self.json_req uri, &b
    JSONRequest.new(uri, &b)
  end

  def self.map
    @map ||= {}
  end
      
  class Styles
    def self.create_view_style opts={}
      `RX.Styles.createViewStyle(#{opts.to_n})`  
    end      

    attr_reader :inherit
    def initialize(h={})
      @h = {}
      @inherit = (h.delete(:inherit) || {})
      merge h
    end
    
    def merge h={}
      h.each_pair do |k,v|
        if v.is_a?(Hash)
          if self[k].is_a?(Styles)
            @h[k] ? @h[k].merge(v) : (@h[k] = self[k].clone(v))
          else
            if self[k]
              n = {}
            
              Hash.new(self[k].to_n).each_pair do |kk,vv|
                n[kk] = vv
              end
              
              v.each_pair do |kk,vv|
                n[kk] = vv
              end
              p n
              @h[k] = Native(RX.style(n))
            else
              @h[k] = Native(RX.style(v))
            
            end
          end
        else
          @h[k] = v
        end
        
      end

      self
    end
    
    def clone h={}
      Styles.new(inherit: self).merge(h)
    end
    
    def [] k
      @h.has_key?(k) ? @h[k] : inherit[k]
    end
    
    def []= k,v
      merge({k=>v})
    end
    
    def keys
      @h.keys
    end
    
    def each_pair &b
      @h.each_pair &b
    end
    
    def each &b
      @h.each &b
    end
    
    def map &b
      @h.map &b
    end
    
    def has_key? k
      @h.has_key?(k) or inherit.has_key?(k)
    end
    
    def delete k
      @h.delete k
    end
    
    def replace h={}, inherit: {}
      @h = {}
      @inherit = inherit
      merge h
    end
    
    def method_missing m,*o,&b
      has_key?(m.to_sym) ? self[m.to_sym].to_n : super
    end
    
    def to_n
      self
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

    def self.styles h={}
      (@styles||=Styles.new(inherit: (h.delete(:inherit) || {})))
      
      @styles.merge h if h
      
      return @styles
    end
    
    def self.style h={}
      Styles.new(h)
    end
    
    def style h=nil
      unless @style
        hh = props[:style] || {}
        hh[:inherit] = self.class.styles
        @style = Styles.new(hh)
      end
      
      @style.merge h if h
      
      @style
    end

    def self.jsx *o, &b
      parent, opts = RX.build_args(*o)
    
      opts[:block] = b
      opts[:opal]  = self
      
      b = nil
      
      e = self.present(self::Base, opts, parent, &b)
      
      e.style opts[:style]
      
      e
    end
    
    def self.replace_text(children, style_sheet=nil)
      children = [children].flatten
          `var h = {};
          
          if (style_sheet) {
            h = {style: #{style_sheet.text}};
          }` if style_sheet[:text]
      
      
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
    
    def self.merge_styles prop, parent
      style = Styles.new
      style.merge parent.style if parent

      style.merge prop if prop
      
      style
    end
    
    def self.rb?(o); `!!o['$$id']` end
    
    def self.present what, opts={}, parent=nil, &b
      children = b.call if b
      
      style = rb?(opts[:style]) ? opts[:style] : nil
      
      if !style and parent
        style = parent.style
      elsif !style and !parent
        style = {}
      elsif !parent and style
       
      end
      
      style ||= {}
      
      children = replace_text(children,style)  unless what == `RX.Text`
      
      children = nil if children.is_a?(Array) and children.empty?
      
      children = `null` if !children
      
      props={}
      
      opts.each_pair do |k,v| props[k]=v end

      if !props[:opal]
        if rb?(props[:style]) and props[:style].is_a?(Styles) and props[:style][:container]
          props[:style] = props[:style].container
        else
          props[:style] = parent.style[:container] if parent
        end
      else
      end
      
      e = RX.create_element(what, props, children)
    
      events opts do |k|
        e.on(:"#{camel_case(k).to_s}") {
          a=[opts[k]]
          
          a << (e.native[:opal] ? e.native[:opal] : e) if parent and parent.method(a[0].to_sym).arity > 0
          
          opts[k].is_a?(Symbol) ? (parent ? parent.send(*a) : send(opts[k])) : opts[k].call(e)
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
    
    def on_mount &b
      if b
        @on_mount = b
      else
        @on_mount.call if @on_mount
      end
      
      self
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
    b = proc do props[:text] end if props[:text]
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
    def initialize what, opts={}, children=nil
      @opts, @what, @children = opts,what,children 
    end
    
    def native
      unless @native
        if @children and `#{@children} != null`
          @native = (Native(`RX.createElement(#{@what}, #{@opts.to_n}, #{@children.to_n})`))    
    
        else
          @native = (Native(`RX.createElement(#{@what}, #{@opts.to_n})`)) 
        end
      end
      
      @native
    end
    
    def to_n
      native.to_n
    end
    
    def on e, &b
      (@opts||={})[:"on#{e.capitalize}"] = proc do
        b.call @native 
      end.to_n
      
      self
    end
    
    def style h=nil
      if o=native[:opal]
        o.style h
      else
        # `console.log("NOOP 'RX.Component' Wrapper#style");`
      end
    end
  end
  
  def self.create_element what, opts={}, children=nil
    e=Element.new(what, opts, children)  
  end

  def self.app(&b)
    @block = proc do |a|
      instance_exec(a, &b)
    end
    
    `OpalRender =  #{@block}`
  end
  
  class Navigator
    SceneConfig = {
      float_from_right: "FloatFromRight",
      float_from_left: "FloatFromLeft",
      fade:             "Fade"
    }
      
    attr_reader :navigator
    def initialize style: `undefined`
      @ref = proc do |n|
        on_ref(n)
      end
    
      @render = proc do |opts|
        s = render_scene(Native(opts))
        s ? s.to_n : `null`
      end

      opts = `{ref: #{@ref}, renderScene: #@render, cardStyle: #{style}}`
    
      @native = Native(`window.OpalNav(#{opts})`)
    end
    
    def render_scene opts={}; end
    
    def on_ref n
      @navigator = Native(n)
    end
    
    def render &b
      RX.build &b
    end
    
    def to_n
      @native.to_n
    end
    
    def nav to, transition: :float_from_right, data: nil
      
      `#{@navigator.to_n}.push({
            routeId: #{to},
            sceneConfigType: #{SceneConfig[transition] || transition},
            data: #{data}
      })`  
      
      true
    end
    
    def back
      `#{@navigator.to_n}.pop()`
    end
    
    def init opts = {}
      o={routeId: "main", sceneConfigType: "FloatFromRight"}
      
      opts.each_pair do |k,v|
        o[k] = v
      end
      
      `#{@navigator.to_n}.immediatelyResetRouteStack([#{o.to_n}])`
    end
  end
  
  def self.img(path)
    p path
    return path if RX::Platform::TYPE == 'web'
    `window.OpalAppGetImage(#{path})`
  end
  
  module Platform
    TYPE = `RX.Platform.getType()`
  end
  
  class FlexList < RX::Component
    styles(
      list: {
        display: 'flex',
        flex: 0,
        flexDirection: 'row',
        flexWrap: "wrap"
      }    
    )
    
    def render
      RX.ScrollView(self) {
        RX.View(style: style.list) {
          super
        }
      }
    end
  end
  
  def self.FlexList(*o,&b)
    FlexList.jsx(*o, &b)
  end

  class ListView < RX::Component
    styles(
      list: {
        display: 'flex',
        flex: 0,
      }   
    )
    
    def render
      RX.ScrollView(self) {
        RX.View(style: style.list) {super}
      }
    end
  end
  
  def self.ListView(*o,&b)
    ListView.jsx(*o, &b)
  end
end
