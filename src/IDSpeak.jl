module IDSpeak

# Install Python bindings via Conda/pip
# using Conda
# Conda.pip_interop(true)
# Conda.pip("install", "C:\\Program Files\\IDS\\ids_peak\\generic_sdk\\api\\binding\\python\\wheel\\x86_64\\ids_peak-1.4.1.0-cp39-cp39-win_amd64.whl")
# Conda.pip("install", "C:\\Program Files\\IDS\\ids_peak\\generic_sdk\\ipl\\binding\\python\\wheel\\x86_64\\ids_peak_ipl-1.3.2.7-cp39-cp39-win_amd64.whl")

using PyCall
using Images

function __init__()
    py"""
    import sys
    from ids_peak import ids_peak as peak
    from ids_peak_ipl import ids_peak_ipl

    m_device = None
    m_dataStream = None
    m_node_map_remote_device = None
    buffer = None

    def open_camera():
        global m_device, m_node_map_remote_device
        try:
            device_manager = peak.DeviceManager.Instance() 
            device_manager.Update()

            if device_manager.Devices().empty():
                return False

            device_count = device_manager.Devices().size()
            for i in range(device_count):
                if device_manager.Devices()[i].IsOpenable():
                    m_device = device_manager.Devices()[i].OpenDevice(peak.DeviceAccessType_Control)
                    m_node_map_remote_device = m_device.RemoteDevice().NodeMaps()[0]
                    return True
        except Exception as e:
            str_error = str(e)

        return False

    def prepare_acquisition():
        global m_dataStream
        try:
            data_streams = m_device.DataStreams()
            if data_streams.empty():
                print("Hello")
                return False
            
            m_dataStream = m_device.DataStreams()[0].OpenDataStream()
            return True
        except Exception as e:
            str_error = str(e)
        
        return False

    def alloc_and_announce_buffers():
        global buffer
        try:
            if m_dataStream:
                m_dataStream.Flush(peak.DataStreamFlushMode_DiscardAll)
                for buffer in m_dataStream.AnnouncedBuffers():
                    m_dataStream.RevokeBuffer(buffer)

                payload_size = m_node_map_remote_device.FindNode("PayloadSize").Value()
                num_buffers_min_required = m_dataStream.NumBuffersAnnouncedMinRequired()
                for count in range(num_buffers_min_required):
                    buffer = m_dataStream.AllocAndAnnounceBuffer(payload_size)
                    m_dataStream.QueueBuffer(buffer)

            return True
        except Exception as e:
            str_error = str(e)
        
        return False

    def start_acquisition(FPS):
        try:
            m_dataStream.StartAcquisition(peak.AcquisitionStartMode_Default, peak.DataStream.INFINITE_NUMBER)
            m_node_map_remote_device.FindNode("AcquisitionFrameRate").SetValue(FPS)
            m_node_map_remote_device.FindNode("TLParamsLocked").SetValue(1)
            m_node_map_remote_device.FindNode("AcquisitionStart").Execute()
        
            return True
        except Exception as e:
            str_error = str(e)

        return False

    def stop_acquisition():
        try:
            remote_nodemap = m_device.RemoteDevice().NodeMaps()[0]
            remote_nodemap.FindNode("AcquisitionStop").Execute()

            m_dataStream.KillWait()
            m_dataStream.StopAcquisition()
            m_dataStream.Flush()

        except Exception as e:
            str_error = str(e)

    def process_image():
        try:
            buffer = m_dataStream.WaitForFinishedBuffer(5000)
            
            image = ids_peak_ipl.Image_CreateFromSizeAndBuffer(
                buffer.PixelFormat(),
                buffer.BasePtr(),
                buffer.Size(),
                buffer.Width(),
                buffer.Height()
            )
            image = image.ConvertTo(ids_peak_ipl.PixelFormatName_BGRa8, ids_peak_ipl.ConversionMode_Fast)
            m_dataStream.QueueBuffer(buffer)
            return image

        except Exception as e:
            print("WTF")
            str_error = str(e)

    def saveimage(image, fp):
        ids_peak_ipl.ImageWriter.Write(fp, image)
    """
end

initialize_camera() = py"peak.Library.Initialize"()
open_camera() = py"open_camera"()
prepare_acquisition() = py"prepare_acquisition"()
alloc_and_announce_buffers() = py"alloc_and_announce_buffers"()
start_acquisition(FPS) = py"start_acquisition"(FPS)
acquire_image() = py"process_image"()
stop_acquisition() = py"stop_acquisition"()
close_camera() = py"peak.Library.Close"()

save_image(image, path) = py"saveimage"(image, path)

function image_preview(image)
    img = image.get_numpy_1D() |> x -> reshape(x, 4, 2592, 1944)
    colorview(RGBA, img / 255) |> restrict |> transpose 
end

end 
