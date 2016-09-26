package = "xamla-xgl"
version = "scm-1"

source = {
   url = "git://github.com/Xamla/xamla-xgl.git",
}

description = {
   summary = "Xamla Open-GL Renderer",
   detailed = [[
   ]],
   homepage = "http://www.xamla.com/",
   license = "BSD"
}

dependencies = {
   "torch >= 7.0"
}

build = {
   type = "command",
   build_command = [[
cmake -E make_directory build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$(PREFIX)" && $(MAKE)
]],
   install_command = "cd build && $(MAKE) install"
}
