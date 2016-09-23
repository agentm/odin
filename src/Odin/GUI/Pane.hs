{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase       #-}
{-# LANGUAGE TupleSections    #-}
{-# LANGUAGE RecordWildCards  #-}
module Odin.GUI.Pane
  ( Pane(..)
  , slotPane
  , renderPane
  , resizePane
  , offsetPane
  ) where

import           Gelatin.SDL2 hiding (move, scale, rotate)
import           SDL
import           Odin.Core
import           Odin.GUI.Common
import           Odin.GUI.Layer
import           Odin.GUI.Picture
import           Control.Lens ((.=), (^.))
import           Control.Monad.Trans.State.Strict

fint :: V2 Int -> V2 Float
fint = (fromIntegral <$>)
--------------------------------------------------------------------------------
-- Pane
--------------------------------------------------------------------------------
data PaneState = PaneStatePassive
               | PaneStateScrolling
               | PaneStateScrolled
               deriving (Show, Eq)

data Pane = Pane { paneContentOffset    :: V2 Int
                 , paneContentSize      :: V2 Int
                 , paneHorizontalScroll :: Slot GUIRenderer
                 , paneVerticalScroll   :: Slot GUIRenderer
                 , paneLayer            :: Slot Layer
                 , paneState            :: PaneState
                 , paneId               :: Int
                 }

paneScrollbarColor :: V4 Float
paneScrollbarColor = V4 1 1 1 0.5

paneScrollbarExtent :: Float
paneScrollbarExtent = 16

paneVerticalScrollPic :: Monad m => Float -> ColorPictureT m ()
paneVerticalScrollPic h = setGeometry $ fan $
  mapVertices (, paneScrollbarColor) $ rectangle 0 (V2 paneScrollbarExtent h)

paneHorizontalScrollPic :: Monad m => Float -> ColorPictureT m ()
paneHorizontalScrollPic w = setGeometry $ fan $
  mapVertices (, paneScrollbarColor) $ rectangle 0 (V2 w 16)

-- | The minimum (but negative) offset the content should move in each dimension
-- of a window pane.
paneMaxContentOffset :: V2 Int -> V2 Int -> V2 Float
paneMaxContentOffset layerSize paneContentSize = V2 w h
  where w = max 0 w0
        h = max 0 h0
        V2 w0 h0 = fint paneContentSize - fint layerSize

-- | The suggested size of the horizontal and vertical scroll bars.
paneScrollSize :: V2 Int -> V2 Int -> V2 Float
paneScrollSize layerSize paneContentSize = V2 clampw clamph
  where clampw  = max 0 w
        clamph  = max 0 h
        V2 w h  = pane * (min 1 <$> (pane / content))
        pane    = fromIntegral <$> layerSize
        content = fromIntegral <$> paneContentSize

-- | The maximum distance the scrollbars should move in each dimension of a
-- window pane.
maxScrollBarPos :: V2 Int -> V2 Int -> V2 Float
maxScrollBarPos layerSize paneContentSize = fint layerSize - sbsize
  where sbsize = paneScrollSize layerSize paneContentSize

-- | The suggested position of the horizontal and vertical scroll bars.
scrollBarPos :: V2 Int -> V2 Int -> V2 Int -> V2 Float
scrollBarPos layerSize paneContentSize paneContentOffset = maxpos * percnt
  where maxpos = maxScrollBarPos layerSize paneContentSize
        minoff = paneMaxContentOffset layerSize paneContentSize
        offset = fint paneContentOffset
        percnt = fnan <$> (offset / minoff)
        fnan t = if isNaN t then 0 else t

mouseUnitsToContentOffset :: V2 Int -> V2 Int -> V2 Int -> V2 Int
mouseUnitsToContentOffset layerSize paneContentSize units =
  floor <$> (maxoff * percnt)
  where maxpos = maxScrollBarPos layerSize paneContentSize
        maxoff = paneMaxContentOffset layerSize paneContentSize
        percnt = fint units / maxpos

clampContentOffset :: V2 Int -> V2 Int -> V2 Int -> V2 Int
clampContentOffset layerSize paneContentSize (V2 x y) = newoffset
  where V2 mxx mxy = floor <$> paneMaxContentOffset layerSize paneContentSize
        newoffset = V2 (max 0 $ min mxx x) (max 0 $ min mxy y)

slotPane :: (GUI s m, Windowed s m) => V2 Int -> V2 Int -> V4 Float -> m (Slot Pane)
slotPane wsz csz color = do
  let V2 sw sh = paneScrollSize wsz csz
  (_,hscrl) <- slotColorPicture $ paneHorizontalScrollPic sw
  (_,vscrl) <- slotColorPicture $ paneVerticalScrollPic sh
  layer     <- slotLayer wsz color
  k         <- fresh
  slot $ Pane 0 csz hscrl vscrl layer PaneStatePassive k

resizePane :: GUI s m => Slot Pane -> V2 Int -> m ()
resizePane s size = do
  p@Pane{..} <- unslot s
  reslotLayer paneLayer size
  let V2 sw sh = paneScrollSize size paneContentSize
  (_,hscrl) <- slotColorPicture $ paneHorizontalScrollPic sw
  (_,vscrl) <- slotColorPicture $ paneVerticalScrollPic sh
  reslot s p{paneHorizontalScroll=hscrl
              ,paneVerticalScroll=vscrl
              }

offsetPane :: GUI s m => Slot Pane -> V2 Int -> m ()
offsetPane s offset0 = do
  p@Pane{..}  <- unslot s
  Layer{..} <- unslot paneLayer
  let offset = clampContentOffset layerSize paneContentSize offset0
  reslot s p{paneContentOffset=offset}

-- | Renders the pane giving the subrendering the content offset.
renderPane :: GUI s m
           => Slot Pane -> [RenderTransform] -> (V2 Int -> m a) -> m a
renderPane s rs f = do
  p@Pane{..}  <- unslot s
  Layer{..} <- unslot paneLayer

  -- determine the mouse position with respect to the layer origin
  mpos0       <- getMousePosition
  canActivate <- getCanBeActive
  let mv    = inv44 $ affine2sModelview $ extractSpatial rs
      mposf = transformV2 mv (fromIntegral <$> mpos0)
      -- determine if the mouse is over the layer
      bb          = (0, fromIntegral <$> layerSize)
      mouseIsOver = canActivate && pointInBounds mposf bb
      -- determine if the mouse is over either scrollbar
      V2 dx dy = scrollBarPos layerSize paneContentSize paneContentOffset
      V2 hw vh = paneScrollSize layerSize paneContentSize
      ext  = paneScrollbarExtent
      vsbb = (V2 0 dy, V2 ext (dy + vh))
      hsbb = (V2 dx 0, V2 (dx + hw) ext)
      mouseIsOverScroll = canActivate &&
        (pointInBounds mposf vsbb || pointInBounds mposf hsbb)
      -- determine the local ui state to use for the layer
      uiblocked = paneState == PaneStateScrolling || mouseIsOverScroll
                                                 || not mouseIsOver
      localState = do
        mousePos .= (floor <$> mposf)
        when uiblocked $ activeId .= UiItemBlocked
      -- a function to render the scrollbars
      renderScrollBars x y = do
        renderPicture paneHorizontalScroll $ move x 0:rs
        renderPicture paneVerticalScroll $ move 0 y:rs
  -- Run the nested rendering function using the layer's ui state to
  -- account for the pane's affine transformation, as well as
  -- attempting to cancel UI activity if the mouse is outside of the visible
  -- pane area.
  (childUI, a) <- uiLocal (execState localState) $
    renderLayer paneLayer rs $ f $ (-1) * paneContentOffset
  -- update the outer ui with the possibly active id
  when (childUI^.activeId /= UiItemBlocked) $ do
    ui.activeId .= childUI^.activeId
    ui.systemCursor .= childUI^.systemCursor

  case paneState of
    PaneStateScrolling -> do
      setActive paneId
      -- if the user still has the mouse down, scroll by the amount the mouse
      -- has moved, relative to its last position
      isDown <- queryMouseButton ButtonLeft
      if isDown
        then do rel <- use (ui . mousePosRel)
                let inc = mouseUnitsToContentOffset layerSize paneContentSize rel
                offsetPane s $ paneContentOffset + inc
                -- show the "clutching" hand
                ui.systemCursor .= SDL_SYSTEM_CURSOR_SIZEALL
        else reslot s p{paneState=PaneStateScrolled}
    _ -> do
      -- if the mouse is over the scrollbars (and can activate),
      -- set the cursor to a hand if the user is over the scrollbars
      when mouseIsOverScroll $ do
        ui.systemCursor .= SDL_SYSTEM_CURSOR_HAND
        isDown <- queryMouseButton ButtonLeft
        -- if the user is also holding down the left mouse, start scrolling
        -- next render
        when isDown $
          reslot s p{paneState=PaneStateScrolling}

  -- render the scrollbars
  renderScrollBars dx dy
  -- return the result of the layer rendering
  return a