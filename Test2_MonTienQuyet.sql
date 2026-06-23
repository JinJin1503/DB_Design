-- ============================================================
-- Test 2: Kiểm thử môn tiên quyết
-- Mô tả: Sinh viên SV001 (Ngô Gia Khánh) chưa có điểm môn CSDL nhưng cố đăng ký môn HTTT.
-- ============================================================
USE QuanLyDangKyHocPhan
GO

DECLARE @Res INT, @Msg NVARCHAR(200);
EXEC SP_DangKyHocPhan 'SV001', 'HTTT_01', @Res OUTPUT, @Msg OUTPUT;
SELECT 'TEST MÔN TIÊN QUYÊT' AS KichBan, @Res AS MaLoi, @Msg AS ThongBaoHethong;
-- Kết quả trả về sẽ là: "Chưa đạt môn tiên quyết."