-- hcullide -- simple test program
-- Author: Matthew Danish.  License: BSD3 (see LICENSE file)
--
-- Simple test of the Cullide library.  There is a bunch of spheres
-- bouncing around an enclosed space.  They turn red when they
-- collide.  You can change direction of orthographic projection using
-- x, y, and z keys.

module Main where

import Graphics.Collision.Cullide
import Graphics.UI.GLUT
import Data.IORef ( IORef, newIORef )
import System.Exit ( exitWith, ExitCode(ExitSuccess) )
import System.Random

data Axis = AxisX | AxisY | AxisZ
data State = State { objs :: IORef [(Vector3d, Vector3d, IO ())]
                   , axisOf :: IORef Axis }

boundMinX = -2
boundMaxX = 2
boundMinY = -2
boundMaxY = 2
boundMinZ = -2
boundMaxZ = 2

light0Position = Vertex4 1 1 1 0
light0Ambient = Color4 0.25 0.25 0.25 1
light0Diffuse = Color4 1 1 1 1

numObjs = 5
objW = 0.3

frameDelay = floor (1000.0 / 60.0)

makeState0 = do
  let qstyle = (QuadricStyle (Just Smooth) GenerateTextureCoordinates Outside FillStyle)
  let w = objW
  dl1 <- defineNewList Compile (renderQuadric qstyle $ Sphere w 18 9)
  let actions = map (\ _ -> callList dl1)
                    [ 1 .. numObjs ]
  objs <- flip mapM actions $ \ a -> do
    p <- randomVector3d
    v <- randomVector3d
    return (p, vecScale (0.01 / magnitude v) v, a)
  r_objs <- newIORef objs
  r_axis <- newIORef AxisZ
  return $ State r_objs r_axis

main :: IO ()
main = do
  (progName, _args) <- getArgsAndInitialize
  initialDisplayMode $= [ DoubleBuffered, RGBMode, WithDepthBuffer ]
  initialWindowSize $= Size 640 480
  initialWindowPosition $= Position 100 100
  createWindow progName
  myInit
  state0 <- makeState0
  displayCallback $= display state0
  reshapeCallback $= Just reshape
  addTimerCallback frameDelay $ computeFrame state0
  keyboardMouseCallback $= Just (keyboard state0)
  mainLoop

computeFrame state = do
  os <- get (objs state)
  os' <- flip mapM os $ \ (p, v, a) -> do
    let Vector3 x y z = p
    let Vector3 vx vy vz = v
    let v' = Vector3 (if abs x > 1 then -vx else vx) 
                     (if abs y > 1 then -vy else vy)
                     (if abs z > 1 then -vz else vz)
    return (p `vecAdd` v', v', a)
  objs state $= os'

  postRedisplay Nothing
  addTimerCallback frameDelay $ computeFrame state
  
reshape :: ReshapeCallback
reshape size = do
  viewport $= (Position 0 0, size)
  matrixMode $= Projection
  loadIdentity
  frustum (-1.0) 1.0 (-1.0) 1.0 2 10
  lookAt (Vertex3 0 0 4) (Vertex3 0 0 0) (Vector3 0 1 0)
  matrixMode $= Modelview 0

display :: State -> DisplayCallback
display state = do
  os <- get (objs state)

  -- collision detect  
  collides <- detect (scaled (1/3, 1/3, 1/3)) . flip map os $ (\ (p, v, a) -> do
    preservingMatrix $ do
      translated' p
      a)
  
  clear [ ColorBuffer, DepthBuffer ]
  loadIdentity   -- clear the matrix

  axis <- get (axisOf state)
  case axis of
    AxisX -> rotated (-90) (0, 1, 0)
    AxisY -> rotated ( 90) (1, 0, 0)
    AxisZ -> return ()

  flip mapM_ (zip os collides) $ \ ((p, v, a), c) -> do
    preservingMatrix $ do
      translated' p
      if c then color3d (1, 0, 0) else color3d (0, 1, 1)
      a

  swapBuffers

myInit :: IO ()
myInit = do
  clearColor $= Color4 0 0 0 0
  shadeModel $= Smooth
  polygonMode $= (Fill, Fill)   -- fill front and back
  colorMaterial $= Just (Front, AmbientAndDiffuse)
  position (Light 0) $= light0Position
  ambient (Light 0) $= light0Ambient
  diffuse (Light 0) $= light0Diffuse
  lighting $= Enabled
  light (Light 0) $= Enabled
  normalize $= Enabled
  depthFunc $= Just Less
  
keyboard :: State -> KeyboardMouseCallback
keyboard state (Char '\27') Down _ _ = exitWith ExitSuccess
keyboard state (Char 'x') Down _ _   = axisOf state $= AxisX
keyboard state (Char 'y') Down _ _   = axisOf state $= AxisY
keyboard state (Char 'z') Down _ _   = axisOf state $= AxisZ
keyboard state _            _    _ _ = return ()

-- utils

randomVector3d :: IO Vector3d
randomVector3d = do
  x <- randomRIO (-1, 1)
  y <- randomRIO (-1, 1)
  z <- randomRIO (-1, 1)
  return $ Vector3 x y z

type Vector3d = Vector3 GLdouble

uncurry3 f (a, b, c) = f a b c
color3d'    = color     :: Color3 GLdouble -> IO ()
color3d     = color3d' . uncurry3 Color3 
scaled'     = scale     :: GLdouble -> GLdouble -> GLdouble -> IO ()
scaled      = uncurry3 scaled'
vertex3d'   = vertex    :: Vertex3 GLdouble -> IO ()
vertex3d    = vertex3d' . uncurry3 Vertex3
normal3d'   = normal    :: Normal3 GLdouble -> IO ()
normal3d    = normal3d' . uncurry3 Normal3
rotated'    = rotate    :: GLdouble -> Vector3d -> IO ()
rotated a   = rotated' a . uncurry3 Vector3
translated' = translate :: Vector3d -> IO ()
translated  = translated' . uncurry3 Vector3

magnitude (Vector3 x y z) = sqrt (x*x + y*y + z*z)
s `vecScale` Vector3 x y z = Vector3 (s*x) (s*y) (s*z)
Vector3 x1 y1 z1 `vecAdd` Vector3 x2 y2 z2 = Vector3 (x1+x2) (y1+y2) (z1+z2)
