funcprot(0);
clear;
xdel(winsid()); // close all previously opened windows
xset('window',20)

exec('particlesUtils.sce', -1)
exec('boxUtils.sce', -1)

path_in='';
path_out='';

raw_file=read_csv(path_in+'100',';');
data=evstr(raw_file);

raw_file2=read_csv(path_in+'0',';');
data2=evstr(raw_file2);

fig=gcf();
fig.figure_size=[1920,1024];
fig.figure_name="Particles";
fig.auto_resize="off"

axes=gca();
axes.data_bounds=[-40,-40,-30;40,40,30];
axes.isoview="on"

param3d1(18, -30, list(3, -10));
param3d1(-7, 12, list(17, -10));
param3d1(0, 20, list(5, -10));
param3d1(-27, -20, list(10, -10));
sleep(4000);

//drawlater();
for i=1:size(data,1),
    drawlater();   
    param3d1(data2(i,1), data2(i,2), list(data2(i,3), -1));//real
    param3d1(data(i,1), data(i,2), list(data(i,3), -9));//melhor
//    param3d1(data(i,13), data(i,14), list(data(i,15), -11));//media
    drawnow();


end
//drawnow();

