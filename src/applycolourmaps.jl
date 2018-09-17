#=----------------------------------------------------------------------------

Copyright (c) 2015 Peter Kovesi
pk@peterkovesi.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

The Software is provided "as is", without warranty of any kind.

----------------------------------------------------------------------------=#

import ColorTypes, Images

export applycolourmap, applydivergingcolourmap, applycycliccolourmap, ternaryimage
export applycolormap, applydivergingcolormap, applycycliccolormap

#-------------------------------------------------------------------------------
"""
applycolourmap/applycolormap: Applies colourmap to a single channel
image to obtain an RGB result

```
Usage: rgbimg = applycolourmap(img, cmap, rnge)

Arguments:  img - Single channel image to apply colourmap to.
                  ::ImageMeta{T,2} or ::Array{Float64,2}
           cmap - RGB colourmap as generated by cmap().
                  ::Array{ColorTypes.RGBA{Float64},1}
           rnge - Optional 2-vector specifying the min and max values in
                  the image to be mapped across the colour map.  Values
                  outside this range are mapped to the end points of the
                  colour map.  If range is omitted the full range
                  of image values are used.

Returns: rgbimg - RGB image of floating point values in the range 0-1.
                  NaN values in the input image are mapped to black.
                  ::ImageMeta{Float64,3} or ::Array{Float64,3}
```
Why use this function when you can simply set a colour map?

Well, actually you probably want to use the functions
applycycliccolourmap() and applydivergingcolourmap() which make use of
this function.

Many visualisation packages may automatically apply an offset and
perform some scaling of your data to normalise it to a range of, say,
0-255 before applying a colour map and rendering it on your screen.
In many cases this is useful. However, if you are wanting to render
your data with a diverging or cyclic colour map then this behaviour is
definitely not appropriate because these types of colour maps requires
that data values are honoured in some way to make any sense.

By providing a 'range' parameter this function allows you to apply a
colour map in a way that respects your data values.

See also: cmap, applycycliccolourmap, applydivergingcolourmap
"""
function applycolourmap(imgin::Array{T,2}, cmap::Array{ColorTypes.RGBA{Float64},1}, rnge::Array) where T
    # This function is also used by relief() as a base image upon which to
    # apply relief shading.

    # November  2013 - Original Matlab code
    # November  2015 - Ported to Julia

    ncolours = length(cmap)
    @assert ndims(imgin) == 2   "Image must be single channel"
    @assert rnge[1] < rnge[2] "rnge[1] must be less than rnge[2]"

    # Convert cmap to a ncolours x 3 array for convenience
    rgbmap = RGBA2FloatArray(cmap)

    img = copy(imgin)
    # Set any Nan entries to rnge[1] so that they will be mapped to the first
    # colour in the colour map without an error being thrown.  Later all NaN
    # regions are set to black.
    mask = isnan.(img)
    img[mask] .= rnge[1]

    # Convert image values to integers that can be used to index into colourmap
    rimg = round.(Int16, (img.-rnge[1])/(rnge[2]-rnge[1]) * (ncolours-1) ) .+ 1

    # Clamp any out of range values (note the values specified in range[] may
    # be well inside the range of values in the image)
    rimg[rimg .< 1] .= 1
    rimg[rimg .> ncolours] .= ncolours

    (rows,cols) = size(img)
    rgbimg = zeros(rows,cols,3)

    for r = 1:rows, c = 1:cols
        rgbimg[r,c,:] = rgbmap[rimg[r,c],:] * !mask[r,c]
    end

    return rgbimg
end

# Case when range is not supplied: use minimum and maximum of image.
# AbstractArray captures both Image and Array{Float64,2}
function applycolourmap(img::AbstractArray, cmap::AbstractArray)
    return applycolourmap(img, cmap, float([minimum(img) maximum(img)]))
end

# Case for img::ImageMeta
function applycolourmap(img::ImageMeta{T,2}, cmap, rnge) where T
    rgbimg = applycolourmap(float(Images.data(img)), cmap, rnge)
    return ImageMeta(rgbimg, colordim = 3, colorspace=Images.RGB,
                        spatialorder = img.properties["spatialorder"])
end

function applycolourmap(img::AbstractArray{T,2}, cmap::Array{Float64, 2}, rnge) where T<:Real
    return applycolourmap(img, FloatArray2RGBA(cmap), rnge)
end


# For those who spell colour without a 'u'
"""
applycolormap: Applies colourmap to a single channel image to obtain
an RGB result
```
Usage: rgbimg = applycolormap(img, cmap, rnge)

Arguments:  img - Single channel image to apply colourmap to.
                  ::ImageMeta{T,2} or ::Array{Float64,2}
           cmap - RGB colourmap as generated by cmap().
                  ::Array{ColorTypes.RGBA{Float64},1}
           rnge - Optional 2-vector specifying the min and max values in
                  the image to be mapped across the colour map.  Values
                  outside this range are mapped to the end points of the
                  colour map.  If range is omitted the full range
                  of image values are used.

Returns: rgbimg - RGB image of floating point values in the range 0-1.
                  NaN values in the input image are rendered as black.
                  ::ImageMeta{Float64,3} or ::Array{Float64,3}

For full documentation see applycolourmap
                                    ^
```
See also: cmap, applycycliccolourmap, applydivergingcolourmap
"""
function applycolormap(imgin::Array{Float64,2}, cmap::Array{ColorTypes.RGBA{Float64},1}, rnge::Array)
    applycolourmap(imgin, cmap, rnge)
end

# Case when range is not supplied: use minimum and maximum of image.
# AbstractArray captures both Image and Array{Float64,2}
function applycolormap(img::AbstractArray, cmap::AbstractArray)
    return applycolourmap(img, cmap, float([minimum(img) maximum(img)]))
end

# Case for img::ImageMeta
function applycolormap(img::ImageMeta{T,2}, cmap, rnge) where T
    rgbimg = applycolourmap(float(Images.data(img)), cmap, rnge)
    return ImageMeta(rgbimg, colordim = 3, colorspace=Images.RGB,
                     spatialorder = img.properties["spatialorder"])
end

function applycolormap(img::AbstractArray{T,2}, cmap::Array{Float64, 2}, rnge) where T<:Real
    return applycolourmap(img, FloatArray2RGBA(cmap), rnge)
end


#------------------------------------------------------------------
"""
ternaryimage:  Perceptualy uniform ternary image from 3 bands of data

This function generates a ternary image using 3 basis colours that are
closely matched in lightness, as are their secondary colours.  The
colours are not as vivid as the RGB primaries but they produce ternary
images with consistent feature salience no matter what permutation of
channel-colour assignement is used.  This is in contrast to ternary
images constructed with the RGB primaries where the channel that
happens to get encoded in green dominates the perceptual result.

Useful for Landsat imagery or radiometric images.

```
Usage: rgbimg = ternaryimage(img; bands, histcut, RGB)

Argument:
            img - Multiband image with at least 3 bands.
                  ::ImageMeta{T,3} or ::Array{T<:Real,3}

Keyword Arguments:
          bands - Array of 3 values indicating the bands, to be assigned to
                  the red, green and blue basis colour maps.  If omitted
                  bands defaults to [1, 2, 3].
        histcut - Percentage of image band histograms to clip.  It can be
                  useful to clip 1-2%. If you see lots of white in your
                  ternary image you have clipped too much. Defaults to 0.
            RGB - Boolean flag, if set to true the classical RGB primaries
                  are used to construct the ternary image rather than the
                  lightness matched primaries. Defaults to false.

Returns:
          rgbimg - RGB ternary image
                  ::ImageMeta{T,3} or ::Array{T<:Real,3}
```
For the derivation of the three primary colours see:
Peter Kovesi. Good Colour Maps: How to Design Them.
arXiv:1509.03700 [cs.GR] 2015.

See also: applycolourmap, linearrgbmap
"""
function ternaryimage(img::Array{T,3}; bands::Array = [1, 2, 3],
                      histcut::Real = 0.0, RGB::Bool=false) where T<:Real

    N = 256
    (rows, cols, chan) = size(img)

    if minimum(bands) < 1 || maximum(bands) > chan
        error("Band specification outside number of image channels")
    end

    if RGB          # Use classical RGB primaries
        R = [1 0 0]
        G = [0 1 0]
        B = [0 0 1]

    else           # Use lightness matched primaries.
                   # For their derivation see the reference above.
        R = [0.90 0.17 0.00]
        G = [0.00 0.50 0.00]
        B = [0.10 0.33 1.00]
    end

    Rmap = equalisecolourmap("rgb", linearrgbmap(R, N))
    Gmap = equalisecolourmap("rgb", linearrgbmap(G, N))
    Bmap = equalisecolourmap("rgb", linearrgbmap(B, N))

    if histcut > eps()
        rgbimg = applycolourmap(histtruncate(img[:,:,bands[1]], histcut), Rmap) +
        applycolourmap(histtruncate(img[:,:,bands[2]], histcut), Gmap) +
        applycolourmap(histtruncate(img[:,:,bands[3]], histcut), Bmap)
    else
        rgbimg = applycolourmap(img[:,:,bands[1]], Rmap) +
        applycolourmap(img[:,:,bands[2]], Gmap) +
        applycolourmap(img[:,:,bands[3]], Bmap)
    end

    return rgbimg
end

# Case for img::ImageMeta  ** Conversion of RGB4 FixedPointNumbers images does not work **
function ternaryimage(img::ImageMeta{T,3};
                      bands::Array = [1, 2, 3], histcut::Real = 0.0, RGB::Bool=false) where T

    rgbimg = ternaryimage(float(Images.data(img)), bands=bands, histcut=histcut, RGB=RGB)
    return ImageMeta(rgbimg, colordim = 3, colorspace=Images.RGB, spatialorder = img.properties["spatialorder"])
end

#------------------------------------------------------------------------------
"""
applycycliccolourmap/applycycliccolormap: Applies a cyclic colour map
to an image of angular data

For angular data to be rendered correctly it is important that the data values
are respected so that data values are correctly assigned to specific entries
in a cyclic colour map.  The assignment of values to colours also depends on
whether the data is cyclic over pi, or 2*pi.

In contrast, default display methods typically do not respect data values
directly and can perform inappropriate offsetting and normalisation of the
angular data before display and rendering with a colour map.

The rendering of the angular data with a specified colour map can be modulated
as a function of an associated image amplitude.  This allows the colour map
encoding of the angular information to be modulated to represent the
amplitude/reliability/coherence of the angular data.

```
Usage: rgbimg = applycycliccolourmap(ang, cmap)
       rgbimg = applycycliccolourmap(ang, cmap, keyword args ...)

Arguments:
           ang - Image of angular data to be rendered
                 ::ImageMeta or ::Array{Float64,2}
          cmap - Cyclic colour map to render the angular data with.

Keyword arguments:

           amp - Amplitude image used to modulate the mapped colours of the
                 angular data.  If not supplied no modulation of colours is
                 performed.
                 ::ImageMeta or ::Array{Float64,2}
   modtoblack  - Boolean flag/1 indicating whether the amplitude image is used to
                 modulate the colour mapped image values towards black,
                 or towards white.  The default is true, towards black.
   cyclelength - The cycle length of the angular data.  Use a value of pi
                 if the data represents orientations, or 2*pi if the data
                 represents phase values.  If the input data is in degrees
                 simply set cycle in degrees and the data will be
                 rendered appropriately. Default is 2*pi.

Returns: rgbim - The rendered image.
                 ::ImageMeta{Float64,3} or ::Array{Float64,3}
```

For a list of all cyclic colour maps that can be generated by cmap() use:

```
> cmap("cyclic")
```

See also: cmap, scalogram, ridgeorient, applycolourmap, applydivergingcolourmap
"""
function applycycliccolourmap(ang::Array{Float64,2}, cmap::Array{ColorTypes.RGBA{Float64},1};
                  amp::Array=Array{Float64}(undef, 0,0), cyclelength::Real=2*pi, modtoblack::Bool=true)
    # September 2014
    # November  2015 Ported to Julia

    # Apply colour map to angular data.  Some care is needed with this.  Unlike
    # normal 'linear' data one cannot apply shifts and/or rescale values to
    # normalise them.  The raw angular data values have to be respected.

    angmod = mod.(ang, cyclelength)   # Ensure data values are within range 0 - cyclelength
    rgbimg = applycolourmap(angmod, cmap, [0, cyclelength])

    if !isempty(amp)   # Display image with rgb values modulated by amplitude
        normamp = normalise(amp)  # Enforce amplitude  0 - 1

        if modtoblack  # Modulate rgb values by amplitude fading to black
            for n = 1:3
                rgbimg[:,:,n] = rgbimg[:,:,n].*normamp
            end

        else           # Modulate rgb values by amplitude fading to white
            for n = 1:3
                rgbimg[:,:,n] = 1 - (1 - rgbimg[:,:,n]).*normamp
            end
        end
    end

    return rgbimg
end

# Case for img::ImageMeta
function applycycliccolourmap(img::ImageMeta{T1,2}, cmap::Array{ColorTypes.RGBA{Float64},1};
                          amp::ImageMeta{T2,2}=ImageMeta(Array{Float64}(undef, 0,0)),
                          cyclelength::Real=2*pi, modtoblack::Bool=true) where {T1,T2}
    rgbimg = applycycliccolourmap(float(Images.data(img)), cmap, amp=float(Images.data(amp)),
                   cyclelength=cyclelength, modtoblack=modtoblack)
    return ImageMeta(rgbimg, colordim = 3, colorspace=Images.RGB, spatialorder = img.properties["spatialorder"])
end


# For those who spell colour without a 'u'
"""
applycycliccolormap:  Applies a cyclic colour map to an image of angular data
```
For full documentation see applycycliccolourmap
                                          ^
```
See also: applycolourmap, applydivergingcolourmap
"""
function applycycliccolormap(ang::Array{Float64,2}, cmap::Array{ColorTypes.RGBA{Float64},1};
                  amp::Array=Array{Float64}(undef, 0,0), cyclelength::Real=2*pi, modtoblack::Bool=true)
    applycycliccolourmap(ang, cmap, amp, cyclelength, modtoblack)
end


# Case for img::ImageMeta
function applycycliccolormap(img::ImageMeta{T1,2}, cmap::Array{ColorTypes.RGBA{Float64},1};
                             amp::ImageMeta{T2,2}=ImageMeta(Array{Float64}(undef, 0,0)),
                             cyclelength::Real=2*pi, modtoblack::Bool=true) where {T1,T2}
    applycycliccolourmap(img, cmap, amp, cyclelength, modtoblack)
end



#------------------------------------------------------------------------------
"""
applydivergingcolourmap/applydivergingcolormap - Applies a diverging
colour map to an image

For data to be displayed correctly with a diverging colour map it is
important that the data values are respected so that the reference value in
the data is correctly associated with the centre entry of a diverging
colour map.

In contrast, default display methods typically do not respect data values
directly and can perform inappropriate offsetting and normalisation of the
data before display and rendering with a colour map.

```
Usage:  rgbim = applydivergingcolourmap(img, map, refval)

Arguments:
           img - Image to be rendered.  ::ImageMeta or ::Array{Float64,2}
           map - Colour map to render the data with.
        refval - Reference value to be associated with centre point of
                 diverging colour map.  Defaults to 0.
Returns:
        rgbimg - The rendered image.
                 ::ImageMeta{Float64,3} or ::Array{Float64,3}
```
For a list of all diverging colour maps that can be generated by cmap()
use: > cmap("div")

See also: applycolourmap, applycycliccolourmap
"""
function applydivergingcolourmap(img::AbstractArray, cmap::AbstractArray, refval::Real = 0.0)

    minv = minimum(img)
    maxv = maximum(img)

    if refval < minv || refval > maxv
        @warn("Reference value is outside the range of image values")
    end

    dr = maximum([maxv - refval, refval - minv])
    rnge = [-dr dr] .+ refval

    return applycolourmap(img, cmap, rnge)
end

# For those who spell colour without a 'u'
"""
applydivergingcolormap - Applies a diverging colour map to an image

```
For full documentation see applydivergingcolourmap
                                             ^
```
See also: applycolourmap, applycycliccolourmap
"""
function applydivergingcolormap(img::AbstractArray, cmap::AbstractArray, refval::Real = 0.0)
    applydivergingcolourmap(img, cmap, refval)
end
