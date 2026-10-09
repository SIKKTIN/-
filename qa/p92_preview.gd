extends SceneTree
func _initialize(): call_deferred("run")
func run():
 OS.set_environment("ESCAPE_TUTORIAL_MODE","on")
 root.size=Vector2i(1200,720)
 root.content_scale_size=root.size
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.tutorial.set_process(false)
 for i in range(1200):
  game._process(0.05)
  if game.tutorial.speaking(): break
 print("READY ",game.tutorial.speaking()," guard=",game.guard.position)
 for i in range(50): game._process(0.05)
 game.tutorial.text_revealed=999
 for size in [Vector2i(1200,720),Vector2i(960,540)]:
  root.size=size
  root.content_scale_size=size
  await process_frame
  game.fullscreen_ui.layout()
  for i in range(60): game._process(0.05)
  game.presentation.tick(0)
  game.tutorial._refresh()
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/tests/p92-welcome-"+str(size.x)+".png")
 quit()
