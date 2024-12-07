# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

bl_info = {
    "name" : "Ahmsville Dial",
    "author" : "Gareth Bradley",
    "description" : "This addon enables space navigation support for the Ahmsville Dial spacenav controller using the cross platform companion app",
    "blender" : (2, 91, 0),
    "version" : (0, 0, 1),
    "location": "View3D > Sidebar > Ahmsville Dial",
    "warning": "Requires installation of dependencies",
    "support": "COMMUNITY",
    "category" : "3D View"
}

import bpy
from mathutils import Quaternion, Vector, Euler
import threading,queue
import os
import sys
import subprocess
import importlib
from collections import namedtuple
import asyncio
import json

Dependency = namedtuple("Dependency", ["module", "package", "name"])

# Declare all modules that this add-on depends on, that may need to be installed. The package and (global) name can be
# set to None, if they are equal to the module name. See import_module and ensure_and_import_module for the explanation
# of the arguments. DO NOT use this to import other parts of your Python add-on, import them as usual with an
# "import" statement.
dependencies = (Dependency(module="websockets", package=None, name=None),)

dependencies_installed = False


# ************************************************************
# ******************** DEPENDENCY LOADING ********************
# ************************************************************

#region
def import_module(module_name, global_name=None, reload=True):
    """
    Import a module.
    :param module_name: Module to import.
    :param global_name: (Optional) Name under which the module is imported. If None the module_name will be used.
       This allows to import under a different name with the same effect as e.g. "import numpy as np" where "np" is
       the global_name under which the module can be accessed.
    :raises: ImportError and ModuleNotFoundError
    """
    if global_name is None:
        global_name = module_name

    if global_name in globals():
        importlib.reload(globals()[global_name])
    else:
        # Attempt to import the module and assign it to globals dictionary. This allow to access the module under
        # the given name, just like the regular import would.
        globals()[global_name] = importlib.import_module(module_name)


def install_pip():
    """
    Installs pip if not already present. Please note that ensurepip.bootstrap() also calls pip, which adds the
    environment variable PIP_REQ_TRACKER. After ensurepip.bootstrap() finishes execution, the directory doesn't exist
    anymore. However, when subprocess is used to call pip, in order to install a package, the environment variables
    still contain PIP_REQ_TRACKER with the now nonexistent path. This is a problem since pip checks if PIP_REQ_TRACKER
    is set and if it is, attempts to use it as temp directory. This would result in an error because the
    directory can't be found. Therefore, PIP_REQ_TRACKER needs to be removed from environment variables.
    :return:
    """

    try:
        # Check if pip is already installed
        subprocess.run([sys.executable, "-m", "pip", "--version"], check=True)
    except subprocess.CalledProcessError:
        import ensurepip

        ensurepip.bootstrap()
        os.environ.pop("PIP_REQ_TRACKER", None)


def install_and_import_module(module_name, package_name=None, global_name=None):
    """
    Installs the package through pip and attempts to import the installed module.
    :param module_name: Module to import.
    :param package_name: (Optional) Name of the package that needs to be installed. If None it is assumed to be equal
       to the module_name.
    :param global_name: (Optional) Name under which the module is imported. If None the module_name will be used.
       This allows to import under a different name with the same effect as e.g. "import numpy as np" where "np" is
       the global_name under which the module can be accessed.
    :raises: subprocess.CalledProcessError and ImportError
    """
    if package_name is None:
        package_name = module_name

    if global_name is None:
        global_name = module_name

    # Blender disables the loading of user site-packages by default. However, pip will still check them to determine
    # if a dependency is already installed. This can cause problems if the packages is installed in the user
    # site-packages and pip deems the requirement satisfied, but Blender cannot import the package from the user
    # site-packages. Hence, the environment variable PYTHONNOUSERSITE is set to disallow pip from checking the user
    # site-packages. If the package is not already installed for Blender's Python interpreter, it will then try to.
    # The paths used by pip can be checked with `subprocess.run([bpy.app.binary_path_python, "-m", "site"], check=True)`

    # Create a copy of the environment variables and modify them for the subprocess call
    environ_copy = dict(os.environ)
    environ_copy["PYTHONNOUSERSITE"] = "1"

    subprocess.run([sys.executable, "-m", "pip", "install", package_name], check=True, env=environ_copy)

    # The installation succeeded, attempt to import the module again
    import_module(module_name, global_name)

class AHMSVILLE_DIAL_PT_warning_panel(bpy.types.Panel):
    bl_label = "Example Warning"
    bl_category = "Example Tab"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"

    @classmethod
    def poll(self, context):
        return not dependencies_installed

    def draw(self, context):
        layout = self.layout

        lines = [f"Please install the missing dependencies for the \"{bl_info.get('name')}\" add-on.",
                 f"1. Open the preferences (Edit > Preferences > Add-ons).",
                 f"2. Search for the \"{bl_info.get('name')}\" add-on.",
                 f"3. Open the details section of the add-on.",
                 f"4. Click on the \"{AHMSVILLE_DIAL_OT_install_dependencies.bl_label}\" button.",
                 f"   This will download and install the missing Python packages, if Blender has the required",
                 f"   permissions.",
                 f"If you're attempting to run the add-on from the text editor, you won't see the options described",
                 f"above. Please install the add-on properly through the preferences.",
                 f"1. Open the add-on preferences (Edit > Preferences > Add-ons).",
                 f"2. Press the \"Install\" button.",
                 f"3. Search for the add-on file.",
                 f"4. Confirm the selection by pressing the \"Install Add-on\" button in the file browser."]

        for line in lines:
            layout.label(text=line)


class AHMSVILLE_DIAL_OT_install_dependencies(bpy.types.Operator):
    bl_idname = "example.install_dependencies"
    bl_label = "Install dependencies"
    bl_description = ("Downloads and installs the required python packages for this add-on. "
                      "Internet connection is required. Blender may have to be started with "
                      "elevated permissions in order to install the package")
    bl_options = {"REGISTER", "INTERNAL"}

    @classmethod
    def poll(self, context):
        # Deactivate when dependencies have been installed
        return not dependencies_installed

    def execute(self, context):
        try:
            install_pip()
            for dependency in dependencies:
                install_and_import_module(module_name=dependency.module,
                                          package_name=dependency.package,
                                          global_name=dependency.name)
        except (subprocess.CalledProcessError, ImportError) as err:
            self.report({"ERROR"}, str(err))
            return {"CANCELLED"}

        global dependencies_installed
        dependencies_installed = True

        # Register the panels, operators, etc. since dependencies are installed
        loadAfterDependencies()

        return {"FINISHED"}

#endregion

# ********************************************************
# ******************** AHMSVILLE CODE ********************
# ********************************************************

#region

# class AHMSVILLE_DIAL_OT_ahmsville_dial_controls(bpy.types.Operator):
#     """Activate spacenav"""
#     bl_idname = "wm.ahmsville_dial_controls"
#     bl_label = "Ahmsville Dial Panel"
#     bl_options = {'REGISTER', 'UNDO'}

#     alreadystarted = False
    
#     dialon: bpy.props.BoolProperty(
#         name='Activate',
#         description='Activate the ahmsville dial addon',
#         default=True
#     )
#     translate_zoom: bpy.props.BoolProperty(
#         name='Translate and Zoom',
#         description='switch slide axis between translate(left/right) + zoom and translate only' ,
#         default=False
#     )
#     tiltsensitivity: bpy.props.FloatProperty(
#         name='Tilt Sensitivity',
#         description='adjust rotation sensitivity',
#         default=1,
#         max=4,
#         min=0.1
#     )
#     slidesensitivity: bpy.props.FloatProperty(
#         name='Slide Sensitivity',
#         description='adjust Translation sensitivity',
#         default=1,
#         max=4,
#         min=0.1
#     )
#     rollsensitivity: bpy.props.FloatProperty(
#         name='Roll Sensitivity',
#         description='adjust roll sensitivity',
#         default=0.01,
#         max=0.5,
#         min=0.005
#     )
#     def execute(self, context):
#         if not self.alreadystarted:
#             # bpy.ops.wm.modal_ahmsville_dial()
#             self.alreadystarted = True
#         return {'FINISHED'}

class AhmsvilleDialData:
    def __init__(self, message):
        
        jsonData = json.loads(message)
        self.gyroX = float(jsonData['gyroX'])
        self.gyroY = float(jsonData['gyroY'])
        self.gyroRad = float(jsonData['gyroRad'])
        self.planarX = float(jsonData['planarX'])
        self.planarY = float(jsonData['planarY'])
        self.knob1 = float(jsonData['knob1'])
        self.knob2 = float(jsonData['knob2'])
        self.buttonEvents = jsonData['buttonEvents']
    
class AhmsvilleDialOperator(bpy.types.Operator):
    """Operator which runs its self from a timer"""
    bl_idname = "wm.modal_ahmsville_dial"
    bl_label = "Ahmsville Dial Operator"
   
    #limits : bpy.props.IntProperty(default=0) #not 'limits ='

    q = queue.Queue()
    eventdone = False
    disconnectpipe = False
    interpolationfactor = 5
    ratio = 0.8
    dial = None
    previous_dial = None
    #_timer = None
    
    
    def modal(self, context, event):
        
        if event.type == 'TIMER':
            while not q.empty():
                res = q.get()

                if self.dial is not None:
                    self.previous_dial = self.dial

                self.dial = AhmsvilleDialData(res)

                if (self.dial.buttonEvents and len(self.dial.buttonEvents) > 0):
                    print(self.dial.buttonEvents)

                

                self.move(context, -self.dial.gyroY / 2000, self.dial.gyroX / 2000, -self.dial.planarY / 1000, -self.dial.planarX / 1000)

                if (self.previous_dial is not None and self.dial is not None and self.previous_dial.knob2 != self.dial.knob2):
                    if (self.dial.knob2 < (self.previous_dial.knob2 - 2)):
                        self.rollleft(context)
                    elif (self.dial.knob2 > (self.previous_dial.knob2 + 2)):
                        self.rollright(context)

                if (self.previous_dial is not None and self.dial is not None and self.previous_dial.knob1 != self.dial.knob1):
                    zoom = rollangle = bpy.data.scenes["Scene"].ahmsville_props.zoomsensitivity

                    if (self.dial.knob1 < (self.previous_dial.knob1 - 0)):
                        self.zoom(context, zoom)
                    elif (self.dial.knob1 > (self.previous_dial.knob1 + 0)):
                        self.zoom(context, -zoom)

           
            
        return {'PASS_THROUGH'}

    def execute(self, context):
        global q
        global eventdone
        # global viewports_3D
        global t1
        try:

            # C = bpy.context
            # viewports_3D = []
            # for area in C.screen.areas:
            #     if area.type == 'VIEW_3D':
            #         viewports_3D.append(area)
            #         override = bpy.context.copy()
            #         override['area'] = area
            q = queue.Queue()
            t1 = threading.Thread(target=self.websocket_thread, args=(context,))
            t1.daemon = True
            t1.start()
            wm = context.window_manager
            self._timer = wm.event_timer_add(time_step=0.0001, window=context.window)
            wm.modal_handler_add(self)

        except Exception as err:
            print(f'execute: Unhandled Exception', err)

        return {'RUNNING_MODAL'}

    def cancel(self, context):
        wm = context.window_manager
        wm.event_timer_remove(self._timer)

    def websocket_thread(self, context):
        print('Starting websocket thread')
        
        try:
            asyncio.run(self.websocket_client(context))
        except Exception as err:
            print(f'websocket_thread: Unhandled Exception', err)


    async def websocket_client(self, context):
        uri = "ws://localhost:23425/ws"

        try:
            print('Starting websocket client', bpy.data.scenes["Scene"].ahmsville_props.dialon)
            async with websockets.connect(uri, ping_interval=None, ping_timeout=5, close_timeout=2) as websocket:
                while bpy.data.scenes["Scene"].ahmsville_props.dialon == True:
                    try:
                        message = await websocket.recv()
                        # jsonMessage = json.load(message)

                        q.put(message)
                        # self.move(context, 0.1, 0.1, 0, 0)
                        # print(f'Message:', message)
                    except websockets.ConnectionClosed as e:
                        print(f'Terminated', e)
                        continue
                    except TimeoutError as e:
                        print('timeout!')
                        continue
                    except Exception as e:
                        print(f'websocket_client loop: Unhandled Exception', e)

                # We've broken out of the loop because we've disabled the device.
                await websocket.close()
                print('Websocket closed')

        except Exception as err:
            print(f'websocket_client: Unhandled Exception', err)


    def move(self,context,xang,yang,zoom,transd): 
        # C = bpy.context
        viewports_3D = []
        for area in bpy.context.screen.areas:
            if area.type == 'VIEW_3D':
                viewports_3D.append(area)
                override = context.copy()
                override['area'] = area
                
                vm = viewports_3D[0].spaces.active.region_3d.view_matrix
                currentQuat = Quaternion(viewports_3D[0].spaces.active.region_3d.view_rotation)
                currentQuatinv = currentQuat.copy()
                currentQuatinv.conjugate()
                rightaxis = Quaternion([0,1,0,0])
                upaxis = Quaternion([0,0,1,0])
                nq = currentQuat.cross(rightaxis).cross(currentQuatinv)
                right_vec = Vector([vm[0][0],vm[0][1],vm[0][2]])
                nq2 = currentQuat.cross(upaxis).cross(upaxis)
                up_vec = Vector([vm[1][0],vm[1][1],vm[1][2]])
                tiltsense = bpy.data.scenes["Scene"].ahmsville_props.tiltsensitivity
                rotright = Quaternion(right_vec,xang*tiltsense)
                rotup = Quaternion(up_vec,yang*tiltsense)
                #print('right_vec  {}'.format(right_vec))
                #print('up_vec  {}'.format(up_vec))
                #print('rotright  {}'.format(rotright))
                #print('rotup  {}'.format(rotup))
                #print('finalrotq  {}'.format(finalrotq))
                #viewports_3D[0].spaces.active.region_3d.view_rotation.rotate(Euler((0, 0, 0.01)))
                viewports_3D[0].spaces.active.region_3d.view_rotation.rotate(rotright)
                viewports_3D[0].spaces.active.region_3d.view_rotation.rotate(rotup)
                slidesense = bpy.data.scenes["Scene"].ahmsville_props.slidesensitivity
                tvec = viewports_3D[0].spaces.active.region_3d.view_location - (right_vec*transd*slidesense)
                
                transmode = bpy.data.scenes["Scene"].ahmsville_props.translate_zoom
                if transmode:
                    viewports_3D[0].spaces.active.region_3d.view_location = tvec
                    viewports_3D[0].spaces.active.region_3d.view_distance += zoom
                else:
                    tvec = tvec - (up_vec*zoom*slidesense)
                    viewports_3D[0].spaces.active.region_3d.view_location = tvec
                viewports_3D[0].spaces.active.region_3d.update()
                    
                #print('/                                                    /')
    def zoomtofit(self,context):
        try:
            selobj = bpy.context.selected_objects
            if selobj == []:
                keyboard = Controller()
                homekey = Key.home
                keyboard.press(homekey)
                keyboard.release(homekey)
            else:
                keyboard = Controller()
                deckey = KeyCode.from_vk(0x6E)
                keyboard.press(deckey)
                keyboard.release(deckey)
        except Exception as e:
            ...
    def rollright(self,context):
        C = bpy.context
        viewports_3D = []
        for area in C.screen.areas:
            if area.type == 'VIEW_3D':
                viewports_3D.append(area)
                override = bpy.context.copy()
                override['area'] = area 
                vm = viewports_3D[0].spaces.active.region_3d.view_matrix
                forward_vec = Vector([vm[2][0],vm[2][1],vm[2][2]])
                # rollangle = context.window_manager.operator_properties_last("wm.ahmsville_dial_controls").rollsensitivity
                rollangle = bpy.data.scenes["Scene"].ahmsville_props.rollsensitivity
                roll_FT = (rollangle * (1 - self.ratio)) / (1 - pow(self.ratio, self.interpolationfactor))
                for i in range(self.interpolationfactor):
                    roll = Quaternion(forward_vec, (roll_FT * pow(self.ratio, (i))))
                    viewports_3D[0].spaces.active.region_3d.view_rotation.rotate(roll)
                    viewports_3D[0].spaces.active.region_3d.update()

        ...
    def rollleft(self,context):
        C = bpy.context
        viewports_3D = []
        for area in C.screen.areas:
            if area.type == 'VIEW_3D':
                viewports_3D.append(area)
                override = bpy.context.copy()
                override['area'] = area 
                vm = viewports_3D[0].spaces.active.region_3d.view_matrix
                forward_vec = Vector([vm[2][0],vm[2][1],vm[2][2]])
                # rollangle = context.window_manager.operator_properties_last("wm.ahmsville_dial_controls").rollsensitivity
                rollangle = bpy.data.scenes["Scene"].ahmsville_props.rollsensitivity
                roll_FT = (rollangle * (1 - self.ratio)) / (1 - pow(self.ratio, self.interpolationfactor))
                for i in range(self.interpolationfactor):
                    roll = Quaternion(forward_vec, -(roll_FT * pow(self.ratio, (i))))
                    viewports_3D[0].spaces.active.region_3d.view_rotation.rotate(roll)
                    viewports_3D[0].spaces.active.region_3d.update()

    def zoom(self,context,zoom): 
        # C = bpy.context
        viewports_3D = []
        for area in bpy.context.screen.areas:
            if area.type == 'VIEW_3D':
                viewports_3D.append(area)
                override = context.copy()
                override['area'] = area
                
                # currentQuat = Quaternion(viewports_3D[0].spaces.active.region_3d.view_rotation)
                # currentQuatinv = currentQuat.copy()
                # currentQuatinv.conjugate()
                zoom_FT = (zoom * (1 - self.ratio)) / (1 - pow(self.ratio, self.interpolationfactor))

                for i in range(self.interpolationfactor):
                    viewports_3D[0].spaces.active.region_3d.view_distance += zoom_FT
                    viewports_3D[0].spaces.active.region_3d.update()
        

class AHMSVILLE_DIAL_OT_keymap(bpy.types.Operator):
    bl_idname = "ahmsville.keymap_op"
    bl_label = "Toggle Ahmsville Dial"
    bl_description = "Toggles the Ahmsville Dial on/off (only affects Blender)"
    bl_options = {"REGISTER"}

    def execute(self, context):
        # print(matplotlib.get_backend())
        bpy.data.scenes["Scene"].ahmsville_props.dialon = not bpy.data.scenes["Scene"].ahmsville_props.dialon
        return {"FINISHED"}

def changeFunc(name, self, context):
    if (name == 'dialon' and bpy.data.scenes["Scene"].ahmsville_props.dialon == True):
        bpy.ops.wm.modal_ahmsville_dial()
        # ShowMessageBox('Started Dial!')

class AhmsvilleSettings(bpy.types.PropertyGroup):
    dialon: bpy.props.BoolProperty(
        name='Activate the Ahmsville Dial',
        description='Activate the ahmsville dial addon',
        default=True,
        update=lambda self, context: changeFunc('dialon', self, context)
    )
    translate_zoom: bpy.props.BoolProperty(
        name='Translate and Zoom',
        description='switch slide axis between translate(left/right) + zoom and translate only' ,
        default=False
    )
    tiltsensitivity: bpy.props.FloatProperty(
        name='Tilt Sensitivity',
        description='adjust rotation sensitivity',
        default=1,
        max=4,
        min=0.1
    )
    slidesensitivity: bpy.props.FloatProperty(
        name='Slide Sensitivity',
        description='adjust Translation sensitivity',
        default=1,
        max=4,
        min=0.1
    )
    rollsensitivity: bpy.props.FloatProperty(
        name='Roll Sensitivity',
        description='adjust roll sensitivity',
        default=0.002,
        max=0.5,
        min=0.001
    )
    zoomsensitivity: bpy.props.FloatProperty(
        name='Zoom Sensitivity',
        description='adjust zoom sensitivity',
        default=0.5,
        max=5,
        min=0.001
    )

def ShowMessageBox(message = "", title = "Message Box", icon = 'INFO'):

    def draw(self, context):
        self.layout.label(text=message)

    bpy.context.window_manager.popup_menu(draw, title = title, icon = icon)

class AHMSVILLE_DIAL_PT_panel(bpy.types.Panel):
    bl_label = "Ahmsville Dial Panel"
    bl_idname = "AHMSVILLE_DIAL_PT_panel"
    bl_category = "Ahmsville Dial"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"



    def draw(self, context):
        layout = self.layout
        scene = context.scene
        ahmsville_props = scene.ahmsville_props

        row = layout.row()
        row.prop(ahmsville_props, "dialon")

        row = layout.row()
        # row.label(text='Translate zoom:')
        row.prop(ahmsville_props, 'translate_zoom', expand=True)

        row = layout.row()
        # row.label(text='Tilt sensitivity:')
        row.prop(ahmsville_props, 'tiltsensitivity', expand=True)

        row = layout.row()
        # row.label(text='Slide sensitivity:')
        row.prop(ahmsville_props, 'slidesensitivity', expand=True)

        row = layout.row()
        # row.label(text='Roll sensitivity:')
        row.prop(ahmsville_props, 'rollsensitivity', expand=True)

        row = layout.row()
        # row.label(text='Roll sensitivity:')
        row.prop(ahmsville_props, 'zoomsensitivity', expand=True)



class AHMSVILLE_DIAL_preferences(bpy.types.AddonPreferences):
    bl_idname = __name__
    
    @classmethod
    def poll(self, context):
        # Deactivate when dependencies have been installed
        return not dependencies_installed
    
    def draw(self, context):
        layout = self.layout
        layout.operator(AHMSVILLE_DIAL_OT_install_dependencies.bl_idname, icon="CONSOLE")

#endregion

# **************************************************
# ******************** KEY MAPS ********************
# **************************************************

#region

keys = {"MENU": [{"label": "Activate Ahmsville Dial",
                  "region_type": "WINDOW",
                  "space_type": "VIEW_3D",
                  "map_type": "KEYBOARD",
                  "keymap": "3D View",
                  "idname": AHMSVILLE_DIAL_OT_keymap.bl_idname,
                  "type": "W",
                  "ctrl": True,
                  "alt": False,
                  "shift": False,
                  "oskey": False,
                  "value": "PRESS"
                  },]}

def get_keys():
    keylists = []
    keylists.append(keys["MENU"])
    return keylists
        
def register_keymaps(keylists):
    wm = bpy.context.window_manager
    kc = wm.keyconfigs.addon

    keymaps = []

    for keylist in keylists:
        for item in keylist:
            keymap = item.get("keymap")
            space_type = item.get("space_type", "EMPTY")
            region_type = item.get("region_type", "WINDOW")

            if keymap:
                km = kc.keymaps.new(name=keymap, space_type=space_type, region_type=region_type)
                # km = kc.keymaps.new(name=keymap, space_type=space_type)

                if km:
                    idname = item.get("idname")
                    type = item.get("type")
                    value = item.get("value")

                    shift = item.get("shift", False)
                    ctrl = item.get("ctrl", False)
                    alt = item.get("alt", False)
                    oskey = item.get("oskey", False)

                    kmi = km.keymap_items.new(idname, type, value, shift=shift, ctrl=ctrl, alt=alt, oskey=oskey)

                    if kmi:
                        properties = item.get("properties")

                        if properties:
                            for name, value in properties:
                                setattr(kmi.properties, name, value)

                        keymaps.append((km, kmi))
    return keymaps

def unregister_keymaps(keymaps):
    for km, kmi in keymaps:
        km.keymap_items.remove(kmi)

#endregion

# *****************************************************
# ******************** BOILERPLATE ********************
# *****************************************************

#region

# Classes to load on registry
preference_classes = (AhmsvilleSettings,
                      AHMSVILLE_DIAL_PT_warning_panel,
                      AHMSVILLE_DIAL_OT_install_dependencies,
                      AHMSVILLE_DIAL_preferences)

# Classes to load after dependencies
classes = (AhmsvilleDialOperator,
           AHMSVILLE_DIAL_PT_panel,
           AHMSVILLE_DIAL_OT_keymap,)

def loadAfterDependencies():
    for cls in classes:
        bpy.utils.register_class(cls)
    
    # Add the hotkey
    global keymaps
    keys = get_keys()
    keymaps = register_keymaps(keys)

def register():
    global dependencies_installed
    dependencies_installed = False

    for cls in preference_classes:
        bpy.utils.register_class(cls)

    bpy.types.Scene.ahmsville_props = bpy.props.PointerProperty(type=AhmsvilleSettings)

    try:
        for dependency in dependencies:
            import_module(module_name=dependency.module, global_name=dependency.name)
        dependencies_installed = True
    except ModuleNotFoundError:
        # Don't register other panels, operators etc.
        return

    loadAfterDependencies()

    


def unregister():
    del bpy.types.Scene.ahmsville_props

    for cls in preference_classes:
        bpy.utils.unregister_class(cls)

    if dependencies_installed:
        for cls in classes:
            bpy.utils.unregister_class(cls)

    # Remove the hotkey
    global keymaps
    unregister_keymaps(keymaps)

if __name__ == "__main__":
    register()

#endregion