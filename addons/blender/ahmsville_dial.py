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
    "author" : "Ahmsville Labs",
    "description" : "This addon enables space navigation support for the Ahmsville Dial spacenav controller",
    "blender" : (2, 80, 0),
    "version" : (0, 0, 1),
    "location" : "",
    "warning" : "",
    "category" : "Generic"
}

import bpy
from mathutils import Quaternion, Vector, Euler
from math import acos, atan2, sqrt, sin, cos
import time,datetime
from copy import copy, deepcopy
import threading,queue
import sys
import win32pipe, win32file, pywintypes
import random
from pynput.keyboard import Key, Controller,KeyCode

class WM_OT_ahmsville_dial_controls(bpy.types.Operator):
    """Activate spacenav"""
    bl_idname = "wm.ahmsville_dial_controls"
    bl_label = "Ahmsville Dial Panel"
    bl_options = {'REGISTER', 'UNDO'}

    alreadystarted = False
    
    dialon: bpy.props.BoolProperty(
        name='Activate',
        description='Activate the ahmsville dial addon',
        default=True
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
        default=0.01,
        max=0.5,
        min=0.005
    )
    def execute(self, context):
        if not self.alreadystarted:
            bpy.ops.wm.modal_ahmsville_dial()
            self.alreadystarted = True
        return {'FINISHED'}
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
    #_timer = None
    
    
    def modal(self, context, event):
        if event.type == 'TIMER':
            
                #run Dial op
                while not q.empty():
                    res = q.get()
                    #print(res)
                    if '>' in res:
                        ress = context.window_manager.operator_properties_last("wm.ahmsville_dial_controls").dialon
                        if ress == True:
                            floatstrpos = 0
                            datastr = ['','','','']
                            dataflt = [0,0,0,0]
                            for c in res:
                                if c != '\0' and c != '*' and c != '>':
                                    if c == '|':
                                        floatstrpos += 1
                                    else:
                                        datastr[floatstrpos] += c
                            for i in range(len(dataflt)):   
                                dataflt[i] = float(datastr[i])
                            self.move(context,-dataflt[0], -dataflt[1],-dataflt[2],dataflt[3])
                            #print(dataflt) 
                    elif '/' in res:
                        functionname = ""
                        for c in res:
                            if c != '/' and c != '*' and c != '\0':
                                functionname += c
                        if functionname == 'BLENDER_zoomToFit':
                            self.zoomtofit(context)
                        elif functionname == 'BLENDER_roll_right':
                            self.rollright(context)
                        elif functionname == 'BLENDER_roll_left':
                            self.rollleft(context)
                    elif '^' in res:
                        configname = ""
                        for c in res:
                            if c != '^' and c != '*' and c != '\0':
                                configname += c
                        if configname == 'slmodeTrue':
                            context.window_manager.operator_properties_last("wm.ahmsville_dial_controls").translate_zoom = True
                        elif configname == 'slmodeFalse':
                            context.window_manager.operator_properties_last("wm.ahmsville_dial_controls").translate_zoom = False
                        elif 'rollsense' in configname:
                            rollsenseval = float(configname.replace('rollsense',''))
                            context.window_manager.operator_properties_last("wm.ahmsville_dial_controls").rollsensitivity = rollsenseval/100
                            #print('rollsense ==  {}'.format(rollsenseval/100))
                            ...
                        
				
           
            
        return {'PASS_THROUGH'}

    def execute(self, context):
        global q
        global eventdone
        global viewports_3D
        global t1
        C = bpy.context
        viewports_3D = []
        for area in C.screen.areas:
            if area.type == 'VIEW_3D':
                viewports_3D.append(area)
                override = bpy.context.copy()
                override['area'] = area
        q = queue.Queue()
        t1 = threading.Thread(target=self.pipe_server)
        t1.daemon = True
        t1.start()
        wm = context.window_manager
        self._timer = wm.event_timer_add(time_step=0.0001, window=context.window)
        wm.modal_handler_add(self)
        return {'RUNNING_MODAL'}

    def cancel(self, context):
        wm = context.window_manager
        wm.event_timer_remove(self._timer)

    
    def pipe_server(self):
        res = -1
        global hPipe
        global disconnectpipe
        disconnectpipe = False
        while res == -1: 
            try:
                hPipe = win32pipe.CreateNamedPipe(
                r'\\.\pipe\blender',            # pipe name 
                win32pipe.PIPE_ACCESS_INBOUND,     # read/write access  
                win32pipe.PIPE_TYPE_BYTE | win32pipe.PIPE_TYPE_BYTE | win32pipe.PIPE_WAIT,    # message-type pipe # message-read mode # blocking mode                
                1,               # number of instances 
                65536,   # output buffer size 
                65536,   # input buffer size 
                0,            # client time-out 
                None)                # default security attributes   
                try:
                    #print("waiting for client")
                    res = win32pipe.ConnectNamedPipe(hPipe, None)
                    if res == 2:
                        break
                        #print("got client")
                        ...
                    res = self.getpipedata(hPipe)
                    if res == -1:
                        ...
                finally:
                    #win32pipe.DisconnectNamedPipe(hPipe)
                    win32file.CloseHandle(hPipe)
                    #res = 0
            except pywintypes.error as e:
                #print(e.args[0])
                ...
        print("finished now")
            
    def getpipedata(self,hPipe):
        elapsed_time_ms = 0
        t_start = datetime.datetime.now()
        error = 0
        while elapsed_time_ms < 1000:  
            #print(f"Reading message") 
            while error != 109:
                t_start = datetime.datetime.now()
                singlebuff = [b'0',b'0']
                output = "" 
                try:
                    while singlebuff[1].decode("utf-8") != '*':
                        peakres = win32pipe.PeekNamedPipe(hPipe, 1)
                        if peakres[0] != '':
                            singlebuff = win32file.ReadFile(hPipe, 1)
                            if singlebuff[1] != '':
                                output += singlebuff[1].decode("utf-8") 
                        else:
                            singlebuff = '*'
                    if output != "":
                        #mymouse = Controller()
                        #mymouse.move(0,0)
                        q.put(output)
                        singlebuff = ' '
                        output = ""
                except pywintypes.error as e:
                    if e.args[0] == 2:
                        #print("no pipe, trying again in a sec")
                        ...
                    elif e.args[0] == 109:
                        error = 109
                        #print("broken pipe, bye bye")
                if disconnectpipe:
                    try:
                        #win32pipe.DisconnectNamedPipe(hPipe)
                        win32file.CloseHandle(hPipe)
                    finally:
                        break
                        #print(e.args[0])
                        ...
            t_end = datetime.datetime.now()
            delta = t_end - t_start
            elapsed_time_ms = delta.total_seconds() * 1000
        return -1
    def move(self,context,xang,yang,zoom,transd): 
        C = bpy.context
        viewports_3D = []
        for area in C.screen.areas:
            if area.type == 'VIEW_3D':
                viewports_3D.append(area)
                override = bpy.context.copy()
                override['area'] = area
                
                #print(viewports_3D[0].spaces.active.region_3d.view_rotation)
                #print(viewports_3D[0].spaces.active.region_3d.view_location)
                #print(viewports_3D[0].spaces.active.region_3d.view_distance)
                print(viewports_3D[0].spaces.active.region_3d.view_matrix)
                #print(viewports_3D[0].spaces.active.region_3d.view_matrix[0])
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
                tiltsense = context.window_manager.operator_properties_last("wm.ahmsville_dial_controls").tiltsensitivity
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
                slidesense = context.window_manager.operator_properties_last("wm.ahmsville_dial_controls").slidesensitivity
                tvec = viewports_3D[0].spaces.active.region_3d.view_location - (right_vec*transd*slidesense)
                
                transmode = context.window_manager.operator_properties_last("wm.ahmsville_dial_controls").translate_zoom
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
                rollangle = context.window_manager.operator_properties_last("wm.ahmsville_dial_controls").rollsensitivity
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
                rollangle = context.window_manager.operator_properties_last("wm.ahmsville_dial_controls").rollsensitivity
                roll_FT = (rollangle * (1 - self.ratio)) / (1 - pow(self.ratio, self.interpolationfactor))
                for i in range(self.interpolationfactor):
                    roll = Quaternion(forward_vec, -(roll_FT * pow(self.ratio, (i))))
                    viewports_3D[0].spaces.active.region_3d.view_rotation.rotate(roll)
                    viewports_3D[0].spaces.active.region_3d.update()
    ...
        

def ahmsvilledial_add_menu_draw(self,context):
    self.layout.operator('wm.ahmsville_dial_controls')
   
addon_keymaps = []
def register():
    bpy.utils.register_class(AhmsvilleDialOperator)
    bpy.utils.register_class(WM_OT_ahmsville_dial_controls)
    bpy.types.VIEW3D_MT_view.append(ahmsvilledial_add_menu_draw)
     # Add the hotkey
    wm = bpy.context.window_manager
    kc = wm.keyconfigs.addon
    if kc:
        km = wm.keyconfigs.addon.keymaps.new(name='3D View', space_type='VIEW_3D')
        kmi = km.keymap_items.new(WM_OT_ahmsville_dial_controls.bl_idname, type='W', value='PRESS', ctrl=True)
        addon_keymaps.append((km, kmi))

def unregister():
     
    

    bpy.utils.unregister_class(AhmsvilleDialOperator)
    bpy.utils.unregister_class(WM_OT_ahmsville_dial_controls)
    bpy.types.VIEW3D_MT_view.remove(ahmsvilledial_add_menu_draw)
    # Remove the hotkey
    for km, kmi in addon_keymaps:
        km.keymap_items.remove(kmi)
    addon_keymaps.clear()
    #terminate pipe
   

if __name__ == "__main__":
    register()
    #bpy.ops.wm.modal_timer_operator()
    ...
    
    