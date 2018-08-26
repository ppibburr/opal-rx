require 'opal'
require 'native'


module RX
  def self.map
    @map ||= {}
  end
      
  
  class Component
    Base = `window.RXBase`
    
    module ClassFuncs
      def self.extended klass
      
      end
    end
    
    def self.inherited klass
      klass.extend ClassFuncs
      RX.map[klass.to_s.gsub("::",'').to_sym] = klass
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

    def self.jsx opts={}, &b
      opts[:block] = b
      opts[:opal] = self
      b = nil
      self.present(self::Base, opts, &b)
    end
    
    def self.present what, opts={}, &b
      children = b.call if b
      `RX.createElement(#{what}, #{opts.to_n}, #{children.to_n})`
    end
    
    def props
      `#{@rx}.props`
    end
    
    attr_reader :rx
    
    def initialize rx
      @rx = rx
      
      `#@rx.state = #{self.class.state.to_n}`
    end
    
    def render
      `#{props()}.block`.call self
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
  
  def self.Text props={}, &b
    Component.present(`RX.Text`, props, &b)
  end

  def self.View props={}, &b
    Component.present(`RX.View`, props, &b)
  end
  
  def self.ScrollView props={}, &b
    Component.present(`RX.ScrollView`, props, &b)
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
      @block = proc do
        if b.call
          
        else
          abort
        end
      end
      
      start if start
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
    
    def stopped? @stopped == true end
    
    def abort
      stop
      @abort = true
    end 
    
    def aborted? @abort == true end
  end
  
  def self.every int, &b
    Interval.new(int, &b)
  end
  
  def self.timeout int, &b
    Interval.new(int) do
      b.call
      
      false
    end
  end
  
  def self.require path
    e=Native `e=document.createElement('SCRIPT')`
    e[:src]="./dist/#{path}.rb.js"
    `document.body.appendChild(#{e})`
  end
end

RX.require 'opal-app'
