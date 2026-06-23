-- ============================================================
-- Test 4: Kiểm thử xuất dữ liệu Thời khóa biểu
-- Mô tả: Gọi SP xuất thời khóa biểu để chứng minh sinh viên SV001 đã sở hữu lớp CSDL_01.
-- ============================================================
USE QuanLyDangKyHocPhan
GO

EXEC SP_XuatThoiKhoaBieu 'SV001', 'HK1_2526';