-- ============================================================
-- Test 3: Kiểm thử luồng Đăng ký thành công & Chặn lớp đầy
-- Mô tả: Lớp CSDL_01 có sĩ số tối đa là 1. SV001 đăng ký trước sẽ thành công. SV002 đăng ký sau sẽ bị hệ thống chặn lại.
-- ============================================================
USE QuanLyDangKyHocPhan
GO
DECLARE @Res INT, @Msg NVARCHAR(200);

-- SV001 đăng ký hợp lệ
EXEC SP_DangKyHocPhan 'SV001', 'CSDL_01', @Res OUTPUT, @Msg OUTPUT;
SELECT 'SV001 DANG KY' AS KichBan, @Res AS MaLoi, @Msg AS ThongBaoHethong;

-- SV002 vào đăng ký ké (sẽ thất bại vì sĩ số đã đạt giới hạn 1/1)
EXEC SP_DangKyHocPhan 'SV002', 'CSDL_01', @Res OUTPUT, @Msg OUTPUT;
SELECT 'SV002 DANG KY' AS KichBan, @Res AS MaLoi, @Msg AS ThongBaoHethong;
-- Kết quả trả về cho SV002 sẽ là: "Lớp học phần đã đầy."