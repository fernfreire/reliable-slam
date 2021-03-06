funcprot(0);
clear;
xdel(winsid()); // close all previously opened windows

rand('seed',1)

// Personal laptop workstation (LINUX)
// path_in='/media/Documents/Etudes/ENSTA-Bretagne/Stages/ENSI3-UFRGS/reliable-slam/workspace/Simulations/Scenarios/2D-4Transponders/';
// path_out='/media/Documents/Etudes/ENSTA-Bretagne/Stages/ENSI3-UFRGS/reliable-slam/workspace/Analysis/FastSLAM/Videos/2D-4Transponders/';

// UFRGS Laptop workstation
// path_in='/home/jeremy/workspace/reliable-slam/workspace/Simulations/Scenarios/2D-4Transponders/'

// Personal laptop workstation (WINDOWS)
// path_in='F:\Etudes\ENSTA-Bretagne\Stages\ENSI3-UFRGS\reliable-slam\workspace\Simulations\Scenarios\2D-4Transponders\';
// path_out='F:\Etudes\ENSTA-Bretagne\Stages\ENSI3-UFRGS\reliable-slam\workspace\Analysis\FastSLAM\Videos\2D-4Transponders\';

raw_file=read_csv(path_in+'2D-4Transponders-Circle.res',';');

// avoid the first comment line + parse strings to double
data=evstr(raw_file(2:size(raw_file,1),:));

// Data Format
// 1            2            3            4             5             6             7              8
// pose_pure.x; pose_pure.y; pose_pure.z; pose_noisy.x; pose_noisy.y; pose_noisy.z; pose_pure.yaw; pose_pure.pitch;
// 9               10              11                12               13            14            15
// pose_pure.roll; pose_noisy.yaw; pose_noisy.pitch; pose_noisy.roll; imu_pure.d²x; imu_pure.d²y; imu_pure.d²z;
// 16             17             18             19               20             21             22
// imu_noisy.d²x; imu_noisy.d²y; imu_noisy.d²z; imu_pure.dtheta; imu_pure.dphi; imu_pure.dpsi; imu_noisy.dtheta;
// 23              24             
// imu_noisy.dphi; imu_noisy.dpsi;
// 25                    26                    27                    28                     29                     30
// loch_doppler_pure.vx; loch_doppler_pure.vy; loch_doppler_pure.vz; loch_doppler_noisy.vx; loch_doppler_noisy.vy; loch_doppler_noisy.vz;
// 31                 32                 33                 34
// transponder1_pure; transponder2_pure; transponder3_pure; transponder4_pure; 
// 35                  36                  37                  38
// transponder1_noisy; transponder1_noisy; transponder1_noisy; transponder1_noisy;

// Number of particles
K_param=500; 

// Number of landmarks
N_param=4;

// Degrees to radians
deg2rad=%pi/180;

// Variance of the heading sensor
Ch=10*(0.02*deg2rad)^2;

// Covariance of the motion noise
Mt=10*[0.04^2 0;
0 (0.01*deg2rad)^2];

// Variance of the range sensor
Cr=10*0.3^2;

global handle;
handle=-1;

global handle_l;
handle_l=-1;

global handle_l2;
handle_l2=-1;

global handle_l3;
handle_l3=-1;

global handle_l4;
handle_l4=-1;

global handle_best;
global handle_best_l1;
global handle_best_l2;
global handle_best_l3;
global handle_best_l4;

handle_best=-1;
handle_best_l1=-1;
handle_best_l2=-1;
handle_best_l3=-1;
handle_best_l4=-1;

// 1 particle is 
// [[w(1:t)] [x_1:t] [y_1:t] [theta_1:t] [mux_l1_1:t] [muy_l1_1:t]  ... [mux_lN_1:t] [muy_lN_1:t] [sigmaxx_l1_1:t] [sigmaxy_l1_1:t] [sigmayx_l1_1:t] [sigmayy_l1_1:t] ... [sigmaxx_lN_1:t] [sigmaxy_lN_1:t] [sigmayx_lN_1:t] [sigmayy_lN_1:t]]
// w=weight
// Particle array (memory)
// It has 3-dimension (time t of the particle, member index of the particle members, index of the particle {k})
P=[];

function [z,u]=parse_data(data,line)
    z=[data(line,10); data(line,35:38)'];
    u=[data(line,28); data(line,24)];
endfunction

// Initialize a particle-set according to the given "a-priori" initial state-vector,
// uniformely distributed in boxes for the robot pose,
// normally distributed for the landmarks position
// init_vector is [w x y theta l1_x l1_y l2_x l2_y...sigma...]
// pose_uncertainty contains the half-width of the pose boxes
function [Y]=init_particle_set(K,N,init_vector,pose_uncertainty)
    Y=zeros(1,4+(2+4)*N,K);
    low=init_vector(2:4)-pose_uncertainty(1:3);
    high=init_vector(2:4)+pose_uncertainty(1:3);
    Y(1,1,1:K)=1/K; // initialize weights

    for i=1:K,
        for j=1:3, // pose & orientation uncertainty
            Y(1,j+1,i)=grand(1,1,'unf',low(j),high(j));
        end
        for j=1:N, // landmarks uncertainty
            sigma=get_landmark_covariance(init_vector,j);
            Y(1,1+4+2*(j-1):1+4+2*(j-1)+1,i)=grand(1,'mn',get_landmark_estimate(init_vector,j),sigma)'; //get_landmark_estimate(init_vector,j); //
            // Particles must carry the covariance matrix of each landmark estimate
            Y(1,4+2*N+1+4*(j-1):4+2*N+1+4*(j-1)+3,i)=[sigma(1,1:2) sigma(2,1:2)];
        end
    end
endfunction

// Get the estimate position of the ith landmark
function [L_pose]=get_landmark_estimate(particle,i)
    L_pose=[particle(1,4+1+(i-1)*2);
    particle(1,4+1+(i-1)*2+1)];
endfunction

// Get the covariance matrix of the ith landmark
function [S]=get_landmark_covariance(particle,i)
    S=[particle(1,4+1+N_param*2+(i-1)*4:4+1+N_param*2+(i-1)*4+1);
    particle(1,4+1+N_param*2+(i-1)*4+2:4+1+N_param*2+(i-1)*4+3)];
endfunction

// Observation function for landmark nb "landmark"
function [z_hat]=h(particle,landmark)
    l_pose=get_landmark_estimate(particle,landmark);
    z_hat=sqrt((particle(2)-l_pose(1))^2+(particle(3)-l_pose(2))^2);
endfunction

// Returns the jacobian of the observation function
function [C]=jacobian_observation(particle,landmark)
    l_pose=get_landmark_estimate(particle,landmark);
    dx=particle(2)-l_pose(1);
    dy=particle(3)-l_pose(2);
    d=sqrt((dx)^2+(dy)^2);
    dx=dx/d;
    dy=dy/d;
    C=[-dx -dy];
endfunction

// From all the measurement vector [theta; d1; d2...] only return the
// measurement corresponding to the landmark nb 'landmark'
function [z]=get_reduced_measurement(z_full,landmark)
    z=z_full(1+landmark);
endfunction

// Update the weight and the kalman filter of the
// landmark nb 'landmark' in the particle
function [particle_res]=update_particle(particle, w, mu, sigma, landmark)
    particle(1,1)=w;
    particle(4+1+(landmark-1)*2:4+1+(landmark-1)*2+1)=mu';
    particle(4+N_param*2+1+(landmark-1)*4:4+N_param*2+1+(landmark-1)*4+3)=[sigma(1,1:2) sigma(2,1:2)];
    particle_res=particle;
endfunction

// Normalize the weights in a particle set
function [Y_res]=normalize_weights(Y)
    total=sum(Y(1,1,:));
    Y(1,1,:)=Y(1,1,:)/total;
    Y_res=Y;
endfunction

// FastSLAM 1.0 algorithm with known correspondances landmarks
function [Y_pos]=fast_slam_1(z, u, Y_prev,dt,mod,resampling_strategy,quartil,std)
    for l=1:4, // loop over all observed landmarks

        if mod==2 then // Resample after each landmark is incorporated
            // Normalize weights
            Y_prev=normalize_weights(Y_prev);
            if  resampling_strategy==1 then // Roulette on the ith quartil
                Y_prev=resampling_roulette(Y_prev,quartil,std);
            else // Roulette over the whole population
                Y_prev=resampling_roulette_2(Y_prev,std);
            end
        end
        for k=1:K_param, // loop over all particles
            particle=Y_prev(1,:,k); // retrieve the k-th particle

            // Don't apply the motion update when incorporating the next landmark
            if l==1 then
                particle=sample_motion_model(particle,u,z(1),dt); // sample pose
            end

            z_hat=h(particle,l);

            H=jacobian_observation(particle,l);
            Sigma=get_landmark_covariance(particle,l);
            x_l=get_landmark_estimate(particle,l);
            z_l=get_reduced_measurement(z,l);
            Q=H*Sigma*H'+Cr; // Measurement covariance
            K=Sigma*H'*inv(Q); // Kalman Gain
            x_l=x_l+K*(z_l-z_hat); // Update mean
            Sigma=(eye(2,2)-K*H)*Sigma; // Update covariance

            w=(1/sqrt(det(2*%pi*Q)))*exp((-1/2)*(z_l-z_hat)'*inv(Q)*(z_l-z_hat)); // weight
            tmp=update_particle(particle, w, x_l, Sigma, l);
            Y_prev(:,:,k)=tmp;

            if mod==3 then // Resample for each particle, for each landmark
                // Normalize weights
                Y_prev=normalize_weights(Y_prev);
                if  resampling_strategy==1 then // Roulette on the ith quartil
                    Y_prev=resampling_roulette(Y_prev,quartil,std);
                else // Roulette over the whole population
                    Y_prev=resampling_roulette_2(Y_prev,std);
                end
            end
        end
    end
    if mod==1 then // Resample after every landmarks are incorporated
        // Normalize weights
        Y_prev=normalize_weights(Y_prev);
        if  resampling_strategy==1 then // Roulette on the ith quartil
            Y_prev=resampling_roulette(Y_prev,quartil,std);
        else // Roulette over the whole population
            Y_prev=resampling_roulette_2(Y_prev,std);
        end
    end
    // return the new particle set
    Y_pos=Y_prev;
endfunction

function [particle]=sample_motion_model(particle_prev,u,theta,dt)
    particle_prev(4)=theta+grand(1,1,'nor',0,sqrt(Ch));
    u=u+grand(1,'mn',zeros(2,1),Mt); // Add noise to the control input
    particle_prev(2:4)=particle_prev(2:4)+[u(1)*dt*cos(particle_prev(4));
    u(1)*dt*sin(particle_prev(4));
    dt*u(2)]';
    particle=particle_prev;
endfunction

// Redraw the mth quartile of the population
function [Y_res]=resampling_roulette(Y,m,std)
    q=quart(Y(1,1,:));
    thres=q(m);
    idx=find(Y(1,1,:)>thres);
    pop_kept=Y(:,:,idx);
    pop_kept=normalize_weights(pop_kept);
    nb_to_redraw=K_param-size(idx,2);
    rand_vect=grand(nb_to_redraw,1,'unf',0,1);
    Y_res=pop_kept;
    for i=1:nb_to_redraw,
        p=get_particle2(pop_kept,rand_vect(i));
        p(2:3)=p(2:3)+grand(1,2,'nor',0,std);
//        for land=1:N_param,
//            p(4+1+(land-1)*2)=p(4+1+(land-1)*2)+grand(1,1,'nor',0,std);
//            p(1,4+1+(land-1)*2+1)=p(1,4+1+(land-1)*2+1)+grand(1,1,'nor',0,std);
//        end
        Y_res(1,:,size(idx,2)+i)=p;
    end
endfunction
// Helper for the roulette-resampling strategy
function [particle]=get_particle(Y,weight)
    w=0;
    particle=[];
    for i=1:size(Y,3),
        w=w+Y(1,1,i);
        if (w>weight) then
            if (i>1) then
                particle=Y(1,:,i-1);
                break;
            else 
                particle=Y(1,:,1);
                break;
            end
        end
    end
endfunction

// Redraw the entire population with a probability proportional to
// the weights of the particles
function [Y_res]=resampling_roulette_2(Y,std)
    Y_res=[];
    rand_vect=grand(K_param,1,'unf',0,1);
    for i=1:K_param,
        p=get_particle(Y,rand_vect(i));
        p(2:3)=p(2:3)+grand(1,2,'nor',0,std); // add some noise to diversify the population
//        for land=1:N_param,
//            p(4+1+(land-1)*2)=p(4+1+(land-1)*2)+grand(1,1,'nor',0,std);
//            p(1,4+1+(land-1)*2+1)=p(1,4+1+(land-1)*2+1)+grand(1,1,'nor',0,std);
//        end
        Y_res(1,:,i)=p;
    end
endfunction

// Helper for the roulette-resampling strategy
function [particle]=get_particle2(Y,weight)
    w=0;
    particle=[];
    for i=1:K_param,
        w=w+Y(1,1,i);
        if (w>weight) then
            if (i>1) then
                particle=Y(1,:,i-1);
                break;
            else 
                particle=Y(1,:,1);
                break;
            end
        end
    end
endfunction

function [Y]=resampling_low_variance()

endfunction

// Plot the best particle of a set
function plot_best(Y)
    global handle_best;
    global handle_best_l1;
    global handle_best_l2;
    global handle_best_l3;
    global handle_best_l4;
    [m,k]=max(Y(1,1,:));
    particle=Y(1,:,k);
    pos=particle(2:3);
    landmarks=particle(4+1:4+2*N_param);

    if handle_best==-1 then
        xpoly(pos(1),pos(2),"marks");
        handle_best=gce();
        handle_best.line_mode="off";
        handle_best.mark_size=0;
        handle_best.mark_mode="on";
        handle_best.mark_style=0;
        handle_best.mark_foreground=color('red');
    else
        handle_best.data=[pos(1) pos(2)];
    end

    if handle_best_l1 ==-1 then
        xpoly(landmarks(1),landmarks(2));
        handle_best_l1=gce();
        handle_best_l1.line_mode="off",
        handle_best_l1.mark_size=0;
        handle_best_l1.mark_mode="on";
        handle_best_l1.mark_style=14;
        handle_best_l1.mark_background=color('blue');
    else
        handle_best_l1.data=[landmarks(1) landmarks(2)];
    end

    if handle_best_l2 ==-1 then
        xpoly(landmarks(3),landmarks(4));
        global handle_l2;
        handle_best_l2=gce();

        handle_best_l2.line_mode="off",
        handle_best_l2.mark_size=0;
        handle_best_l2.mark_mode="on";
        handle_best_l2.mark_style=14;
        handle_best_l2.mark_background=color('orange');
    else
        handle_best_l2.data=[landmarks(3) landmarks(4)];
    end

    if handle_best_l3 ==-1 then
        xpoly(landmarks(5),landmarks(6));
        global handle_l3;
        handle_best_l3=gce();

        handle_best_l3.line_mode="off",
        handle_best_l3.mark_size=0;
        handle_best_l3.mark_mode="on";
        handle_best_l3.mark_style=14;
        handle_best_l3.mark_background=color('green');
    else
        handle_best_l3.data=[landmarks(5) landmarks(6)];
    end

    if handle_best_l4 ==-1 then
        xpoly(landmarks(7),landmarks(8));
        global handle_l4;
        handle_best_l4=gce();

        handle_best_l4.line_mode="off",
        handle_best_l4.mark_size=0;
        handle_best_l4.mark_mode="on";
        handle_best_l4.mark_style=14;
        handle_best_l4.mark_background=color('purple');
    else
        handle_best_l4.data=[landmarks(7) landmarks(8)];
    end
endfunction

// Plot all the particles of a set
function plot_set(Y)
    global handle;
    global handle_l;
    global handle_l2;
    global handle_l3;
    global handle_l4;
    pos=[];
    landmarks=[];

    for k=1:K_param,
        pos=[pos;Y(1,2,k) Y(1,3,k)]
        for j=1:N_param,
            landmarks(k,2*(j-1)+1:2*(j-1)+2)=[get_landmark_estimate(Y(1,:,k),j)'];
        end
    end

    if handle==-1 then
        xpoly(pos(:,1),pos(:,2),"marks");
        handle=gce();
        handle.line_mode="off";
        handle.mark_size=0;
        handle.mark_mode="on";
        handle.mark_style=0;
        handle.mark_foreground=color('red');
    else
        handle.data=[pos(:,1) pos(:,2)];
    end


    if handle_l==-1 then
        xpoly(landmarks(:,1),landmarks(:,2));
        handle_l=gce();
        handle_l.line_mode="off",
        handle_l.mark_size=0;
        handle_l.mark_mode="on";
        handle_l.mark_style=14;
        handle_l.mark_background=color('blue');
    else
        handle_l.data=[landmarks(:,1) landmarks(:,2)];
    end

    if handle_l2==-1 then
        xpoly(landmarks(:,3),landmarks(:,4));
        handle_l2=gce();

        handle_l2.line_mode="off",
        handle_l2.mark_size=0;
        handle_l2.mark_mode="on";
        handle_l2.mark_style=14;
        handle_l2.mark_background=color('orange');
    else
        handle_l2.data=[landmarks(:,3),landmarks(:,4)];
    end

    if handle_l3==-1 then
        xpoly(landmarks(:,5),landmarks(:,6));
        handle_l3=gce();
        handle_l3.line_mode="off",
        handle_l3.mark_size=0;
        handle_l3.mark_mode="on";
        handle_l3.mark_style=14;
        handle_l3.mark_background=color('green');
    else 
        handle_l3.data=[landmarks(:,5) landmarks(:,6)];
    end

    if  handle_l4==-1 then
        xpoly(landmarks(:,7),landmarks(:,8));
        handle_l4=gce();
        handle_l4.line_mode="off",
        handle_l4.mark_size=0;
        handle_l4.mark_mode="on";
        handle_l4.mark_style=14;
        handle_l4.mark_background=color('purple');
    else
        handle_l4.data=[landmarks(:,7) landmarks(:,8)];
    end
endfunction


figure(1);
[p_set]=init_particle_set(K_param,N_param,[0 data(1,1) data(1,2) data(1,7) [20 0]+grand(1,2,'unf',-10,10) [-20 0]+grand(1,2,'unf',-10,10) [0 20]+grand(1,2,'unf',-10,10) [0 -20]+grand(1,2,'unf',-10,10) 16 0 0 16 16 0 0 16 16 0 0 16 16 0 0 16],[0.1 0.1 2*sqrt(Ch)]);
// Axes setup
h_axes = gca();
h_axes.data_bounds = [-35,-35;35,35];

// True robot position
xpoly(0,0);
r=gce();
r.line_mode="off";
r.mark_size=0;
r.mark_mode="on";
r.mark_style=1;
r.mark_background=color('black');

// True landmark positions
xpoly(20,0);
hl1=gce();
hl1.line_mode="off",
hl1.mark_size=0;
hl1.mark_mode="on";
hl1.mark_style=10;
hl1.mark_foreground=color('blue');

xpoly(-20,0);
hl2=gce();
hl2.line_mode="off",
hl2.mark_size=0;
hl2.mark_mode="on";
hl2.mark_style=10;
hl2.mark_foreground=color('orange');

xpoly(0,20);
hl3=gce();
hl3.line_mode="off",
hl3.mark_size=0;
hl3.mark_mode="on";
hl3.mark_style=10;
hl3.mark_foreground=color('green');

xpoly(0,-20);
hl4=gce();
hl4.line_mode="off",
hl4.mark_size=0;
hl4.mark_mode="on";
hl4.mark_style=10;
hl4.mark_foreground=color('purple');
i=0;
drawlater();
plot_set(p_set);
drawnow();
xs2png(gcf(),sprintf(path_out+"imgs/mod1_strategy2_std0.1/CLOUD_%04d.png",i));
for i=1:size(data,1),
    [z,u]=parse_data(data,i);
    p_set=fast_slam_1(z,u,p_set,1,1,1,1,0.1);
    //if i==size(data,1) then
    drawlater();
    plot_set(p_set);

    hl1.data=[20 0];
    hl2.data=[-20 0];
    hl3.data=[0 20];
    hl4.data=[0 -20];
    r.data=[data(i,1) data(i,2)];
    drawnow();
    //end
    xs2png(gcf(),sprintf(path_out+"imgs/narrower_and_bigger_variance/CLOUD_%04d.png",i));
end

//for s=1:3,
//    [p_set]=init_particle_set(K_param,N_param,[0 data(1,1) data(1,2) data(1,7) [20 0]+grand(1,2,'unf',-10,10) [-20 0]+grand(1,2,'unf',-10,10) [0 20]+grand(1,2,'unf',-10,10) [0 -20]+grand(1,2,'unf',-10,10) 16 0 0 16 16 0 0 16 16 0 0 16 16 0 0 16],[5 5 2*sqrt(Ch)]);
//// Axes setup
//h_axes = gca();
//h_axes.data_bounds = [-35,-35;35,35];
//
//// True robot position
//xpoly(0,0);
//r=gce();
//r.line_mode="off";
//r.mark_size=0;
//r.mark_mode="on";
//r.mark_style=1;
//r.mark_background=color('black');
//
//// True landmark positions
//xpoly(20,0);
//hl1=gce();
//hl1.line_mode="off",
//hl1.mark_size=0;
//hl1.mark_mode="on";
//hl1.mark_style=10;
//hl1.mark_foreground=color('blue');
//
//xpoly(-20,0);
//hl2=gce();
//hl2.line_mode="off",
//hl2.mark_size=0;
//hl2.mark_mode="on";
//hl2.mark_style=10;
//hl2.mark_foreground=color('orange');
//
//xpoly(0,20);
//hl3=gce();
//hl3.line_mode="off",
//hl3.mark_size=0;
//hl3.mark_mode="on";
//hl3.mark_style=10;
//hl3.mark_foreground=color('green');
//
//xpoly(0,-20);
//hl4=gce();
//hl4.line_mode="off",
//hl4.mark_size=0;
//hl4.mark_mode="on";
//hl4.mark_style=10;
//hl4.mark_foreground=color('purple');
//i=0;
//drawlater();
//    plot_set(p_set);
//drawnow();
//xs2png(gcf(),sprintf(path_out+"imgs/mod1_strategy1_quart%i_std0.1/CLOUD_%04d.png",s,i));
//    for i=1:size(data,1),
//        [z,u]=parse_data(data,i);
//        p_set=fast_slam_1(z,u,p_set,1,1,1,1,0.1);
//        //if i==size(data,1) then
//        drawlater();
//        plot_set(p_set);
//
//        hl1.data=[20 0];
//        hl2.data=[-20 0];
//        hl3.data=[0 20];
//        hl4.data=[0 -20];
//        r.data=[data(i,1) data(i,2)];
//        drawnow();
//        //end
//        xs2png(gcf(),sprintf(path_out+"imgs/mod1_strategy1_quart%i_std0.1/CLOUD_%04d.png",s,i));
//    end
//end