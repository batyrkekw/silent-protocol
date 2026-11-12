extends Control
var page = 0
var clock = 0.0
const Art = preload("res://scripts/robot_art.gd")
const FontFace = preload("res://assets/fonts/jetbrains-mono.ttf")
func _process(delta: float) -> void:
 clock += delta
 queue_redraw()
func label_at(p:Vector2,value:String,color:Color=Color("b8cbe5")) -> void:
 draw_string(FontFace,p,preload("res://scripts/localization.gd").text(value),HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
func block(p:Vector2,value:String,color:Color) -> void:
 draw_style_box(box(color),Rect2(p,Vector2(145,31)))
 label_at(p+Vector2(9,21),value)
func box(color:Color) -> StyleBoxFlat:
 var b=StyleBoxFlat.new();b.bg_color=color;b.set_corner_radius_all(5);return b
func _draw() -> void:
 var cy=size.y/2
 var t=fmod(clock,4.0)/4.0
 var blue=Color("294c78");var gold=Color("6c512b");var purple=Color("593f76")
 match page:
  0,1:
   for i in 6:draw_rect(Rect2(18+i*48,cy-20,44,40),Color("233b56"),false,1)
   var x=40+t*220
   Art.render(self,Vector2(x,cy),0,0.8)
   label_at(Vector2(335,cy+5),"↑  0,5 с   ↷  0,25 с")
  2:
   block(Vector2(12,4),"Повторить 5 раз",gold)
   block(Vector2(35,43),"↑ Шаг вперёд",blue)
   draw_arc(Vector2(240,cy),24,-PI/2,-PI/2+TAU*t,40,Color("e6b55b"),3,true)
   label_at(Vector2(285,cy+5),"Итерация %d / 5" % (1+int(t*5)))
  3:
   block(Vector2(10,25),"Если свободно",gold)
   var yes=t<0.5
   draw_line(Vector2(155,40),Vector2(220,18 if yes else 65),Color("d4b36d"),2,true)
   block(Vector2(220,0),"Да → ↑ вперёд",blue.lightened(.15) if yes else blue)
   block(Vector2(220,45),"Нет → ↷ поворот",blue if yes else blue.lightened(.15))
  4:
   block(Vector2(10,4),"Таймер T: 3 с",Color("285f63"))
   block(Vector2(10,43),"Пока ДОМА = нет",gold)
   draw_arc(Vector2(245,cy),25,-PI/2,-PI/2+TAU*t,48,Color("70d6cd"),3,true)
   label_at(Vector2(290,cy+5),"T: %.1f с" % (3*(1-t)))
  5:
   Art.render(self,Vector2(40,cy),0,.9);Art.render(self,Vector2(420,cy),2,.9)
   draw_dashed_line(Vector2(70,cy),Vector2(390,cy),purple,2,8)
   draw_circle(Vector2(70+t*320,cy),6,Color("d9a0ff"))
   label_at(Vector2(160,cy-16),"ПРОХОД = " + ("да" if t>.5 else "нет"))
  6:
   var source=Vector2(105,cy)
   draw_circle(source,5,Color("c89ae8"))
   draw_arc(source,12+t*30,0,TAU,40,Color("c89ae8",1-t),2,true)
   Art.render(self,Vector2(130+t*130,cy),1,.8)
   draw_circle(Vector2(430-t*130,cy),9,Color("e87d92"))
   label_at(Vector2(140,16),"Оставить эхо → уйти за стену")
  7:
   Art.render(self,Vector2(35,cy),0,.8)
   block(Vector2(80,25),"Канал подмены",purple)
   draw_dashed_line(Vector2(230,cy),Vector2(420,cy),Color("77cfba"),2,8)
   draw_circle(Vector2(230+t*190,cy),4,Color("77cfba"))
  8,9:
   for i in 3:Art.render(self,Vector2(55+i*70+t*130,cy),i,.8)
   draw_rect(Rect2(360,cy-23,50,46),Color("68cdb3"),false,2)
   label_at(Vector2(420,cy+4),"ВЫХОД")
