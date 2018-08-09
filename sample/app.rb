def p o; `console.log(#{o})` ; end

class BlockComponent < RX::Component
  styles(
    # Applied to root
    container: {
     
    },
    
    # Applied to text nodes descendants of root
    text:      {color: 'red'},
    
    button: {
      container: {backgroundColor: "blue"},
      text:      {color: "white"}
    }
  )
   
  state tick: 1
  
  def initialize rx
    super rx
    RX.every 0.3 do tick; true end 
  end
  
  def render
    RX.View(self) {[
      "Some Text",
      
      RX.Button(self, text:     "Click Me", 
                      style:    style.button, 
                      on_press: :button_pressed),
      super
    ]}
  end
  
  def button_pressed; p 1; end
  def tick;           self[:tick] = self[:tick] + 1; end
end

RX.app {
  RX.ScrollView() {[      
    BlockComponent() { |c|
      ["#{c} tick: #{c[:tick]}"]
    }
  ]}
}
