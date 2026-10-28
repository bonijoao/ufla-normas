def test_render_minimo(render):
    r = render("minimo", corpo="# Introdução\n\nTexto.")
    assert r.ok, r.log
    assert "Texto." in r.depois("INTRODUÇÃO")
